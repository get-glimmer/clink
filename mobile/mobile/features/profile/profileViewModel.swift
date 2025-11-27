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
            // Fetch profile
            let response: PostgrestResponse<Profile> = try await client
                .from("profiles")
                .select()
                .eq("id", value: uuid)
                .single()
                .execute()
            
            var profile = response.value
            
            // Fetch friends count
            let friendsResponse = try await client
                .from("friends")
                .select("user_id", head: false, count: .exact)
                .or("user_id.eq.\(uuid),friend_id.eq.\(uuid)")
                .eq("status", value: "accepted")
                .execute()
            
            profile.friendsCount = friendsResponse.count ?? 0
            self.profile = profile
        } catch {
            print("Failed to fetch profile:", error.localizedDescription)
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
