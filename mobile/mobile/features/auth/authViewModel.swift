import Foundation
import UIKit
import SwiftUI
import Supabase

/**
 * Manages authentication state and user profile data.
 * This class is an ObservableObject, making it suitable for use in SwiftUI views.
 */
@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The user's email address.
    @Published var email: String = ""

    /// The user's password.
    @Published var password: String = ""

    /// The current user's profile.
    @Published var profile: Profile?

    /// A boolean indicating if the user is currently authenticated.
    @Published var isAuthenticated = false

    /// A boolean to track if the authentication check is in progress.
    @Published var isCheckingAuth = true

    /// A boolean to indicate if the user's profile has been loaded.
    @Published var isProfileLoaded = false

    /// A boolean that is true only when both profile and authentication checks are complete.
    @Published var isAppReady = false

    /// A message to display in case of an error.
    @Published var errorMessage: String = ""

    /// The availability status of an email address ("Available" or "Already in use").
    @Published var emailStatus: String? = nil

    /// The color associated with the email status message.
    @Published var emailStatusColor: Color = .white

    /// The Supabase client instance.
    private let client = SupabaseClientManager.shared.client

    init() {
        Task { await initializeApp() }
    }

    // MARK: - Public Methods

    /**
     * Initializes the app by checking the session and loading the profile if the user is authenticated.
     */
    func initializeApp() async {
        await checkSession()
        if isAuthenticated {
            await loadProfile()
        }
        isAppReady = true
    }

    /**
     * Checks the current authentication session.
     */
    func checkSession() async {
        guard let client = self.client else { return }
        do {
            let session = try await client.auth.session
            isAuthenticated = (session.user.id != UUID())
        } catch {
            isAuthenticated = false
        }
        isCheckingAuth = false
    }

    // MARK: - Signup

    /**
     * Signs up a new user.
     * - Parameters:
     * - email: The user's email address.
     * - password: The user's password.
     * - name: The user's full name.
     */
    func signup(email: String, password: String, name: String) async {
        guard let client = client else { return }
        do {
            // 1. Sign up the user
            let result = try await client.auth.signUp(email: email, password: password)
            let userId = result.user.id

            // 2. Update the user's profile
            try await client
                .from("profiles")
                .update(["name": name])
                .eq("id", value: userId.uuidString)
                .execute()

            // 3. Update the view model's state
            self.email = email
            self.isAuthenticated = true

            // 4. Load the user's profile
            await loadProfile()

        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /**
     * Saves the user's profile information.
     * - Parameters:
     * - userId: The user's unique identifier.
     * - phoneNumber: The user's phone number.
     * - name: The user's full name.
     * - username: The user's chosen username.
     * - dob: The user's date of birth.
     * - profileImage: The user's profile image.
     * - email: The user's email address.
     */
    func saveProfile(
        userId: String,
        phoneNumber: String?,
        name: String?,
        username: String?,
        dob: Date?,
        profileImage: UIImage?,
        email: String?,
        affectAuthState: Bool = true
    ) async {
        guard let client = client else { return }

        isAppReady = false
        do {
            var avatarUrl: String? = nil

            // Upload avatar if one is provided
            if let profileImage, let data = profileImage.jpegData(compressionQuality: 0.8) {
                let filePath = "\(userId)/profile.jpg"

                try await client.storage
                    .from("avatars")
                    .upload(filePath, data: data, options: FileOptions(upsert: true))

                if let url = try? client.storage.from("avatars").getPublicURL(path: filePath) {
                    avatarUrl = url.absoluteString
                }
            }

            // Prepare the profile input
            let input = ProfileInput(
                id: userId,
                name: name,
                username: username,
                email: (phoneNumber == nil && !(email?.isEmpty ?? true)) ? email : nil,
                phoneNumber: phoneNumber,
                avatar_url: avatarUrl,
                dob: dob?.ISO8601Format()
            )

            // Upsert the profile data
            try await client
                .from("profiles")
                .upsert(input)
                .execute()

            // Reload the profile
            await loadProfile()
        } catch {
            print("❌ Error saving profile:", error.localizedDescription)
        }

        isAppReady = true
    }

    /**
     * Checks if a username is already in use.
     * - Parameter username: The username to check.
     * - Returns: `true` if the username is available, `false` otherwise.
     */
    func checkUsername(_ username: String) async -> Bool {
        guard let client else { return false }

        do {
            let response: PostgrestResponse<[Profile]> = try await client
                .from("profiles")
                .select("id, username")
                .eq("username", value: username)
                .execute()

            return response.value.isEmpty
        } catch {
            print("Error checking username:", error.localizedDescription)
            return false
        }
    }

    /**
     * Checks if an email is already in use.
     * - Parameter email: The email to check.
     * - Returns: `true` if the email is already in use, `false` otherwise.
     */
    func checkEmailInUse(_ email: String) async -> Bool {
        guard let client = client else { return true }

        do {
            let response: PostgrestResponse<[Profile]> = try await client
                .from("profiles")
                .select("id")
                .eq("email", value: email)
                .execute()

            return !response.value.isEmpty
        } catch {
            print("Error checking email:", error.localizedDescription)
            return true
        }
    }

    /**
     * Validates a password based on a set of rules.
     * - Parameter password: The password to validate.
     * - Returns: `true` if the password is valid, `false` otherwise.
     */
    func validatePassword(_ password: String) -> Bool {
        let hasMin8 = password.count >= 8
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasUpperLower = password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
                            password.rangeOfCharacter(from: .lowercaseLetters) != nil
        return hasMin8 && hasNumber && hasUpperLower
    }

    /**
     * Checks password requirements individually.
     * - Parameter password: The password to check.
     * - Returns: A tuple of booleans indicating if each requirement is met.
     */
    func passwordRequirements(_ password: String) -> (min8: Bool, number: Bool, upperLower: Bool) {
        let min8 = password.count >= 8
        let number = password.rangeOfCharacter(from: .decimalDigits) != nil
        let upperLower = password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
                         password.rangeOfCharacter(from: .lowercaseLetters) != nil
        return (min8, number, upperLower)
    }

    // MARK: - Log In

    /**
     * Logs in the user.
     */
    func logIn() async {
        guard let client = self.client else { return }
        do {
            try await client.auth.signIn(email: email, password: password)
            await loadProfile()
            isAuthenticated = true
            errorMessage = ""
        } catch {
            isAuthenticated = false
            errorMessage = "Invalid email or password"
            print("Login failed:", error.localizedDescription)
        }
    }

    /**
     * Resets the password for a given email.
     * - Parameter email: The email for which to reset the password.
     * - Returns: `true` if the reset email was sent successfully, `false` otherwise.
     */
    func resetPassword(for email: String) async -> Bool {
        guard let client = client else { return false }
        
        do {
            try await client.auth.resetPasswordForEmail(email)
            print("✅ Password reset email sent to \(email)")
            return true
        } catch {
            print("❌ Failed to send reset email:", error.localizedDescription)
            return false
        }
    }

    // MARK: - Logout

    /**
     * Logs out the current user.
     */
    func logout() async {
        guard let client = self.client else { return }
        do {
            try await client.auth.signOut()
            isAuthenticated = false
            profile = nil
            print("✅ Logged out")
        } catch {
            print("Logout failed:", error.localizedDescription)
        }
    }

    // MARK: - Delete Profile

    /**
     * Deletes the current user's account.
     */
//    func deleteAccount() async {
//        guard let client = self.client else { return }
//        do {
//            let user = try await client.auth.session.user
//            
//            try await client
//                .from("profiles")
//                .delete()
//                .eq("id", value: user.id.uuidString)
//                .execute()
//            
//            try await client.auth.signOut()
//            isAuthenticated = false
//            profile = nil
//            
//            print("✅ Profile deleted and logged out")
//        } catch {
//            print("Delete profile error:", error.localizedDescription)
//        }
//    }
    
    // In your AuthViewModel

    

    // In your AuthViewModel

    func deleteAccount() async {
        guard let client = self.client else { return }
        
        do {
            print("Attempting to call Edge Function...")
            _ = try await client.functions.invoke("delete-user-rpc")
            
            isAuthenticated = false
            profile = nil
            
            print("✅ Account deletion successfully triggered via Edge Function.")
        } catch {
            // ✅ THIS NEW CATCH BLOCK WILL DECODE THE DETAILED ERROR
            print("❌ Delete account error occurred. Decoding details...")

            // Check if the error is a specific FunctionsError
            if let functionsError = error as? FunctionsError {
                switch functionsError {
                case .httpError(let code, let data):
                    print("   > HTTP Status Code: \(code)")
                    // Try to decode the raw data into a readable string (JSON)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("   > Raw Error Payload: \(jsonString)")
                    } else {
                        print("   > Could not decode error data.")
                    }
                case .relayError:
                    print("   > Relay Error: \(error)")
                }
            } else {
                // Print any other type of error
                print("   > An unexpected error type occurred: \(error.localizedDescription)")
            }
        }
    }

    /**
     * Updates the user's name.
     * - Parameter newName: The new name to set.
     */
    func updateName(_ newName: String) async throws {
        guard let client = client, let profile = profile else { return }

        let response: PostgrestResponse<Profile> = try await client
            .from("profiles")
            .update(["name": newName])
            .eq("id", value: profile.id)
            .select("*")
            .single()
            .execute()

        self.profile = response.value
        print("✅ Name updated in AuthViewModel: \(self.profile?.name ?? "nil")")
    }
    
    func updateAvatar(userId: String, profileImage: UIImage) async {
        guard let client = client else { return }
        
        do {
            // 1. Convert image to Data
            guard let data = profileImage.jpegData(compressionQuality: 0.8) else { return }
            let filePath = "\(userId)/profile.jpg"
            
            // 2. Upload to Supabase storage
            try await client.storage
                .from("avatars")
                .upload(filePath, data: data, options: FileOptions(upsert: true))
            
            // 3. Get public URL
            guard let url = try? client.storage.from("avatars").getPublicURL(path: filePath) else { return }
            let avatarUrl = url.absoluteString
            
            // 4. Update only avatar_url in profiles
            try await client
                .from("profiles")
                .update(["avatar_url": avatarUrl])
                .eq("id", value: userId)
                .execute()
            
            // 5. Optimistically update local profile (no redirect)
            DispatchQueue.main.async {
                self.profile?.avatar_url = avatarUrl
            }
            
            print("✅ Avatar updated successfully")
        } catch {
            print("❌ Error updating avatar:", error.localizedDescription)
        }
    }


    /**
     * Loads the current user's profile.
     */
    func loadProfile() async {
        guard let client = client else { return }
        do {
            let session = try await client.auth.session
            let user = session.user

            let response: PostgrestResponse<Profile> = try await client
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()

            self.profile = response.value
        } catch {
            print("Failed to load profile:", error.localizedDescription)
        }
    }
}
