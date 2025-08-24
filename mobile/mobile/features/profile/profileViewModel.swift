import SwiftUI
import Supabase

// MARK: - Profile ViewModel
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    
    private let client = SupabaseClientManager.shared.client
    
    // MARK: Fetch profile by uuid
    func fetchProfile(uuid: String) async {
        guard let client = self.client else { return }

        do {
            let response = try await client
                .from("profiles")
                .select()
                .eq("id", value: uuid)
                .execute()

            // response.data is already Data, decode directly
            let decodedProfiles = try JSONDecoder().decode([Profile].self, from: response.data)
            self.profile = decodedProfiles.first

        } catch {
            print("Error fetching profile:", error)
        }
    }

    
    // MARK: Update name
    func updateName(to newName: String) async {
        guard let profile = profile else { return }
        guard let client = self.client else { return }
        
        do {
            try await client
                .from("profiles")
                .update(["name": newName])
                .eq("id", value: profile.id)
                .execute()
            
            self.profile?.name = newName
        } catch {
            print("Error updating name:", error)
        }
    }
    
    // MARK: Update bio
    func updateBio(to newBio: String) async {
        guard let profile = profile else { return }
        guard let client = self.client else { return }
        
        do {
            try await client
                .from("profiles")
                .update(["bio": newBio])
                .eq("id", value: profile.id)
                .execute()
            
            self.profile?.bio = newBio
        } catch {
            print("Error updating bio:", error)
        }
    }
    
    // MARK: Update avatar URL
    func updateAvatar(url: String) async {
        guard let profile = profile else { return }
        guard let client = self.client else { return }
        do {
            try await client
                .from("profiles")
                .update(["avatar_url": url])
                .eq("id", value: profile.id)
                .execute()
            
            self.profile?.avatar_url = url
        } catch {
            print("Error updating avatar:", error)
        }
    }
}
