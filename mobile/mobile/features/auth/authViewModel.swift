import Foundation
import Supabase

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var profile: Profile?
    @Published var isAuthenticated = false
    
    private let client = SupabaseClientManager.shared.client
    
    // MARK: - Sign Up
    func signUp() async {
        guard let client = self.client else { return }
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            let userId = response.user.id
            
            // Insert profile row
            try await client
                .from("profiles")
                .insert([
                    "id": userId.uuidString,
                    "email": email,
                    "name": "",
                    "bio": "",
                    "avatar_url": nil
                ])
                .execute()
            
            await loadProfile()
            isAuthenticated = true
        } catch {
            print("Sign up failed:", error.localizedDescription)
        }
    }
    
    // MARK: - Log In
    func logIn() async {
        guard let client = self.client else { return }
        do {
            try await client.auth.signIn(email: email, password: password)
            await loadProfile()
            isAuthenticated = true
        } catch {
            print("Login failed:", error.localizedDescription)
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
    func deleteProfile() async {
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
    
    // MARK: - Load Profile
    func loadProfile() async {
        guard let client = self.client else { return }
        do {
            let session = try await client.auth.session
            let user = session.user
            
            let response: PostgrestResponse<Profile> = try await client
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()
            
            profile = response.value
        } catch {
            print("Failed to load profile:", error.localizedDescription)
        }
    }
}
