import Foundation
import UIKit
import SwiftUI
import Supabase
import AuthenticationServices

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
    
    @Published var shouldResetLoginFlow = false

    /// The raw (unhashed) nonce held between the Apple auth request and its completion.
    @Published var appleRawNonce: String?
    
    
    @Published var tempFullName: String?
    @Published var tempUsername: String?
    @Published var tempDOB: Date?
    @Published var tempProfileImage: UIImage?
    @Published var tempPhoneNumber: String?
    @Published var tempEmail: String?

    

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
            PushNotificationService.shared.requestPermissionAndRegister()
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
//            await loadProfile()
            
            // Only authenticate if caller wants it
            if affectAuthState {
                self.isAuthenticated = true
            }

        } catch {
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
    
    func validateEmail(_ email: String) -> Bool {
        let emailFormat = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailFormat)
        return emailPredicate.evaluate(with: email)
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

            let session = try await client.auth.session
            let uid = session.user.id.uuidString

            // Save profile with stored values from FinishSignupView
            await saveProfile(
                userId: uid,
                phoneNumber: tempPhoneNumber,
                name: tempFullName,
                username: tempUsername,
                dob: tempDOB,
                profileImage: tempProfileImage,
                email: tempEmail,
                affectAuthState: true
            )

            // Clear temp fields after saving
            tempFullName = nil
            tempUsername = nil
            tempDOB = nil
            tempProfileImage = nil
            tempPhoneNumber = nil
            tempEmail = nil

            await loadProfile()
            isAuthenticated = true
            PushNotificationService.shared.requestPermissionAndRegister()
        } catch {
            isAuthenticated = false
            errorMessage = "Invalid email or password"
        }
    }

    // MARK: - Sign in with Apple

    /**
     * Signs in (or signs up) the user with an Apple identity token via Supabase.
     * - Parameters:
     *   - idToken: The JWT identity token returned by Apple.
     *   - nonce: The raw (unhashed) nonce that was hashed for the Apple request.
     *   - fullName: The user's name — only provided by Apple on the first sign-in.
     */
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async {
        guard let client = client else { return }
        do {
            try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )

            // Apple only sends the name on the very first sign-in — stash it so the
            // profile-completion screen can prefill it for brand-new users.
            if let fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !name.isEmpty { tempFullName = name }
            }

            // Load the profile if one already exists (e.g. an account linked by email).
            // Brand-new Apple users have no row yet; RootView routes them to
            // FinishSignupView to pick a username, which creates the profile.
            await loadProfile()
            isAuthenticated = true
            PushNotificationService.shared.requestPermissionAndRegister()
        } catch {
            isAuthenticated = false
            errorMessage = "Apple sign-in failed"
        }
    }

    // MARK: - Sign in with Google

    /**
     * Signs in (or signs up) the user with a Google identity token via Supabase.
     * Mirrors the Apple flow: Google's SDK manages the nonce internally, so we rely
     * on the dashboard's "Skip nonce checks" being enabled and pass no nonce. The
     * name is stashed into `tempFullName` so FinishSignupView can prefill it; the
     * profile row itself is created there for brand-new users (see `needsProfileSetup`).
     * - Parameters:
     *   - idToken: The OpenID Connect identity token from GoogleSignIn.
     *   - accessToken: The OAuth access token from GoogleSignIn.
     *   - fullName: The user's name from their Google profile, if available.
     */
    func signInWithGoogle(idToken: String, accessToken: String, fullName: String?) async {
        guard let client = client else { return }
        do {
            try await client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
            )

            // Stash the name so the profile-completion screen can prefill it for new users.
            if let fullName, !fullName.isEmpty { tempFullName = fullName }

            // Load the profile if one already exists. Brand-new Google users have no
            // row yet; RootView routes them to FinishSignupView, which creates it.
            await loadProfile()
            isAuthenticated = true
            PushNotificationService.shared.requestPermissionAndRegister()
        } catch {
            print("⚠️ Google sign-in failed: \(error)")
            isAuthenticated = false
            errorMessage = "Google sign-in failed"
        }
    }

    /// True when an authenticated user has no username yet (e.g. a brand-new Apple
    /// sign-in) and must complete profile setup before entering the app.
    var needsProfileSetup: Bool {
        guard isAuthenticated else { return false }
        return profile?.username?.isEmpty ?? true
    }

    /**
     * Resets the password for a given email.
     * - Parameter email: The email for which to reset the password.
     * - Returns: `nil` if the reset email was sent successfully, otherwise an error message to display.
     */
    func resetPassword(for email: String) async -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validateEmail(trimmed) else { return "Please enter a valid email address." }
        guard let client = client else { return "Service unavailable. Please try again later." }

        do {
            try await client.auth.resetPasswordForEmail(trimmed)
            return nil
        } catch {
            print("⚠️ resetPasswordForEmail failed for \(trimmed): \(error)")
            return error.localizedDescription
        }
    }

    // MARK: - Logout

    /**
     * Logs out the current user.
     */
    func logout() async {
        guard let client = self.client else { return }
        do {
            await PushNotificationService.shared.removeDeviceToken()
            try await client.auth.signOut()
            isAuthenticated = false
            profile = nil
        } catch {
        }
    }

    // MARK: - Delete Profile

    /**
     * Deletes the current user's account.
     */
    func deleteAccount() async {
        guard let client = self.client else { return }
        
        do {
            _ = try await client.functions.invoke("delete-user-rpc")

            isAuthenticated = false
            profile = nil
        } catch {
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
            
        } catch {
        }
    }
    
    func updateUsername(_ newUsername: String) async throws {
        guard let client = client, let profile = profile else { return }

        let response: PostgrestResponse<Profile> = try await client
            .from("profiles")
            .update(["username": newUsername])
            .eq("id", value: profile.id)
            .select("*")
            .single()
            .execute()

        self.profile = response.value
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
        }
    }
}
