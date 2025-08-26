import Foundation
import UIKit
import Supabase

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var profile: Profile?
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    @Published var isProfileLoaded = false
    @Published var isAppReady = false // true only when profile + auth check are done
    @Published var errorMessage: String = ""
    
    private let client = SupabaseClientManager.shared.client

    init() {
        Task { await initializeApp() }
    }

    @MainActor
    func initializeApp() async {
        await checkSession()
        if isAuthenticated {
            await loadProfile()
        }
        isAppReady = true  // now everything is loaded
    }


    func checkSession() async {
        guard let client = self.client else { return }
        do {
            let session = try await client.auth.session
            isAuthenticated = (session.user.id != UUID())
        } catch {
            isAuthenticated = false
        }
        isCheckingAuth = false // done checking
    }
    
    // MARK: - Signup
    func signup(email: String, password: String, name: String) async {
        guard let client = client else { return }
        do {
            // 1. Sign up user
            let result = try await client.auth.signUp(email: email, password: password)
            let userId = result.user.id

            // 2. Update profile fields
            try await client
                .from("profiles")
                .update([
                    "name": name,
                ])
                .eq("id", value: userId.uuidString)
                .execute()

            // 3. Update AuthViewModel state
            self.email = email
            self.isAuthenticated = true

            // 4. Load profile immediately
            await loadProfile()

        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // Save Profile Through Phone Number
    // Helper wrapper for encoding Any optional values
    struct AnyEncodable: Encodable {
        let value: Any?

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch value {
            case let v as String: try container.encode(v)
            case let v as Int: try container.encode(v)
            case let v as Bool: try container.encode(v)
            case let v as Double: try container.encode(v)
            case let v as Date: try container.encode(v.ISO8601Format())
            case nil: try container.encodeNil()
            default:
                let context = EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type: \(type(of: value))"
                )
                throw EncodingError.invalidValue(value as Any, context)
            }
        }
    }

    @MainActor
    func saveProfile(
        userId: String,
        phoneNumber: String?,
        name: String?,
        username: String?,
        dob: Date?,
        profileImage: UIImage?,
        email: String?
    ) async {
        guard let client = client else { return }

        isAppReady = false
        do {
            var avatarUrl: String? = nil

            // Upload avatar if exists
            if let profileImage,
               let data = profileImage.jpegData(compressionQuality: 0.8) {
                let filePath = "avatars/\(userId)/profile.jpg"

                // Upload the file
                try await client.storage
                    .from("avatars")
                    .upload(filePath, data: data, options: FileOptions(upsert: true))

                // Get public URL
                if let url = try? client.storage.from("avatars").getPublicURL(path: filePath) {
                    avatarUrl = url.absoluteString
                }
            }

            let profileData: [String: AnyEncodable?] = [
                "id": AnyEncodable(value: userId),
                "phoneNumber": AnyEncodable(value: phoneNumber),
                "email": AnyEncodable(value: phoneNumber == nil ? email : nil),
                "name": AnyEncodable(value: name),
                "username": AnyEncodable(value: username),
                "dob": AnyEncodable(value: dob),
                "avatar_url": AnyEncodable(value: avatarUrl)
            ]
            
            print("Saving profile for userId:", userId, "avatarUrl:", avatarUrl ?? "nil")
            try await client
                .from("profiles")
                .upsert(profileData)
                .execute()

            // Optionally reload profile after saving
            await loadProfile()
        } catch {
            print("❌ Error saving profile:", error.localizedDescription)
        }

        isAppReady = true
    }






    func checkUsername(_ username: String) async -> Bool {
        guard let client else { return false }

        do {
            // Execute the query and decode directly to [Profile]
            let response: PostgrestResponse<[Profile]> = try await client
                .from("profiles")
                .select("id, username")
                .eq("username", value: username)
                .execute() // <-- generic execute

            // response.value contains the decoded array
            return response.value.isEmpty // true if username is available
        } catch {
            print("Error checking username:", error.localizedDescription)
            return false
        }
    }






    @MainActor
    func validatePassword(_ password: String) -> Bool {
        let hasMin8 = password.count >= 8
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasUpperLower = password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
                            password.rangeOfCharacter(from: .lowercaseLetters) != nil
        return hasMin8 && hasNumber && hasUpperLower
    }

    // Optional: helper for individual checks if you want dynamic checkmarks
    @MainActor
    func passwordRequirements(_ password: String) -> (min8: Bool, number: Bool, upperLower: Bool) {
        let min8 = password.count >= 8
        let number = password.rangeOfCharacter(from: .decimalDigits) != nil
        let upperLower = password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
                         password.rangeOfCharacter(from: .lowercaseLetters) != nil
        return (min8, number, upperLower)
    }
    
    // MARK: - Log In
    func logIn() async {
        guard let client = self.client else { return }
        do {
            try await client.auth.signIn(email: email, password: password)
            await loadProfile()
            isAuthenticated = true
            errorMessage = "" // clear any old errors
        } catch {
            isAuthenticated = false
            errorMessage = "Invalid email or password"
            print("Login failed:", error.localizedDescription)
        }
    }
    
    @MainActor
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
    
    // MARK: - Delete Profile (only)
    func deleteAccount() async {
        guard let client = self.client else { return }
        do {
            let user = try await client.auth.session.user
            
            try await client
                .from("profiles")
                .delete()
                .eq("id", value: user.id.uuidString)
                .execute()
            
            // Log out locally after deletion
            try await client.auth.signOut()
            isAuthenticated = false
            profile = nil
            
            print("✅ Profile deleted and logged out")
        } catch {
            print("Delete profile error:", error.localizedDescription)
        }
    }
    
    @MainActor
    func updateName(_ newName: String) async throws {
        guard let client = client, let profile = profile else { return }

        let response: PostgrestResponse<Profile> = try await client
            .from("profiles")
            .update(["name": newName])
            .eq("id", value: profile.id)
            .select("*")
            .single()
            .execute()

        // ✅ Assign profile directly from typed response
        self.profile = response.value

        print("✅ Name updated in AuthViewModel: \(self.profile?.name ?? "nil")")
    }


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
