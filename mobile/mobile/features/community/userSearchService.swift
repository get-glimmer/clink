//
//  userSearchService.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import Foundation
import Supabase

// MARK: - Database Models
// Model that matches your exact database schema
struct UserProfile: Codable, Identifiable {
    let id: String              // uuid as string
    let name: String?           // text (nullable)
    let username: String?       // text (nullable)
    let avatar_url: String?     // text (nullable)
    let bio: String?            // text (nullable)
    let email: String?          // text (nullable)
    let created_at: String?     // timestamp as string
    let dob: String?            // date as string
    let phoneNumber: String?    // text (nullable) - matches your schema exactly
    let friends_table_id: String? // uuid as string (nullable)
}

struct FriendRelation: Codable {
    let user_id: String
    let friend_id: String
    let status: String
    let created_at: Date?
    let updated_at: Date?
}

enum FriendshipStatus: String, Codable {
    case requested = "requested"
    case accepted = "accepted"
    case blocked = "blocked"
    case none = "none" // No relationship exists
    
    var userStatus: UserStatus {
        switch self {
        case .requested:
            return .requested
        case .accepted:
            return .following
        case .blocked, .none:
            return .canFollow
        }
    }
}

// MARK: - Search Results
struct UserSearchResult {
    let profile: UserProfile
    let mutualFriendsCount: Int
    let friendshipStatus: FriendshipStatus
    
    func toSearchUser() -> SearchUser {
        return SearchUser(
            actualUserId: profile.id,
            username: profile.username ?? profile.name ?? "Unknown",
            profileImageName: profile.avatar_url ?? "nav-profile1x",
            mutualFriends: mutualFriendsCount > 0 ? mutualFriendsCount : nil,
            status: friendshipStatus.userStatus
        )
    }
}

// MARK: - Search Service
class UserSearchService: ObservableObject {
    private let supabase = SupabaseClientManager.shared.client
    @Published private var currentUserId: String?
    
    init() {
        getCurrentUserId()
    }
    
    private func getCurrentUserId() {
        Task {
            do {
                if let session = try await supabase?.auth.session {
                    await MainActor.run {
                        self.currentUserId = session.user.id.uuidString
                    }
                }
            } catch {
                print("Error getting current user: \(error)")
            }
        }
    }
    
    // MARK: - Search Users
    func searchUsers(query: String) async throws -> [UserSearchResult] {
        guard let supabase = supabase,
              let currentUserId = currentUserId,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            // Search profiles by name, username, or email
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select("*")
                .or("name.ilike.%\(trimmedQuery)%,username.ilike.%\(trimmedQuery)%,email.ilike.%\(trimmedQuery)%")
                .neq("id", value: currentUserId) // Exclude current user
                .limit(20)
                .execute()
                .value
            
            // Get friendship status and mutual friends for each profile
            var searchResults: [UserSearchResult] = []
            
            for profile in profiles {
                let friendshipStatus = await getFriendshipStatus(with: profile.id)
                let mutualFriendsCount = await getMutualFriendsCount(with: profile.id)
                
                let result = UserSearchResult(
                    profile: profile,
                    mutualFriendsCount: mutualFriendsCount,
                    friendshipStatus: friendshipStatus
                )
                searchResults.append(result)
            }
            
            return searchResults
            
        } catch {
            throw error
        }
    }
    
    // MARK: - Get Suggestions
    func getSuggestedUsers() async throws -> [UserSearchResult] {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            return []
        }
        
        do {
            // Get my friends first
            let myFriends: [FriendRelation] = try await supabase
                .from("friends")
                .select()
                .eq("user_id", value: currentUserId)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            let myFriendIds = myFriends.map { $0.friend_id }
            
            // Get all users except current user first, then filter out friends in Swift
            let allProfiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .neq("id", value: currentUserId)
                .order("created_at", ascending: false)
                .limit(50) // Get more to filter later
                .execute()
                .value
            
            // Filter out friends using Swift instead of SQL
            let profiles = allProfiles.filter { profile in
                !myFriendIds.contains(profile.id)
            }.prefix(10) // Limit to 10 after filtering
            
            var suggestions: [UserSearchResult] = []
            
            // For demo purposes, just return users without requiring mutual friends
            for profile in profiles {
                let mutualFriendsCount = await getMutualFriendsCount(with: profile.id)
                let result = UserSearchResult(
                    profile: profile,
                    mutualFriendsCount: mutualFriendsCount,
                    friendshipStatus: .none
                )
                suggestions.append(result)
            }
            
            return suggestions.sorted { $0.mutualFriendsCount > $1.mutualFriendsCount }
        } catch {
            throw error
        }
    }
    
    // MARK: - Friendship Status
    private func getFriendshipStatus(with userId: String) async -> FriendshipStatus {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            return .none
        }
        
        do {
            // First check if I sent a request to them
            let outgoingRequest: [FriendRelation] = try await supabase
                .from("friends")
                .select()
                .eq("user_id", value: currentUserId)
                .eq("friend_id", value: userId)
                .execute()
                .value
            
            if let request = outgoingRequest.first {
                return FriendshipStatus(rawValue: request.status) ?? .none
            }
            
            // Then check if they sent a request to me
            let incomingRequest: [FriendRelation] = try await supabase
                .from("friends")
                .select()
                .eq("user_id", value: userId)
                .eq("friend_id", value: currentUserId)
                .execute()
                .value
            
            if let request = incomingRequest.first {
                return FriendshipStatus(rawValue: request.status) ?? .none
            }
            
            return .none
        } catch {
            return .none
        }
    }
    
    // MARK: - Mutual Friends
    private func getMutualFriendsCount(with userId: String) async -> Int {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            return 0
        }
        
        do {
            // Get my accepted friends
            let myFriends: [FriendRelation] = try await supabase
                .from("friends")
                .select()
                .eq("user_id", value: currentUserId)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            let myFriendIds = Set(myFriends.map { $0.friend_id })
            
            // Get their accepted friends
            let theirFriends: [FriendRelation] = try await supabase
                .from("friends")
                .select()
                .eq("user_id", value: userId)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            let theirFriendIds = Set(theirFriends.map { $0.friend_id })
            
            // Count the intersection
            return myFriendIds.intersection(theirFriendIds).count
            
        } catch {
            return 0
        }
    }
    
    // MARK: - Send Friend Request
    func sendFriendRequest(to userId: String) async throws {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "UserSearchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Check if there's already a relationship
        let existingRelation: [FriendRelation] = try await supabase
            .from("friends")
            .select()
            .or("and(user_id.eq.\(currentUserId),friend_id.eq.\(userId)),and(user_id.eq.\(userId),friend_id.eq.\(currentUserId))")
            .execute()
            .value
        
        if !existingRelation.isEmpty {
            throw NSError(domain: "UserSearchService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Friendship relationship already exists"])
        }
        
        struct FriendRequest: Encodable {
            let user_id: String
            let friend_id: String
            let status: String
            let favorite: Bool
        }
        
        let friendRequest = FriendRequest(
            user_id: currentUserId,
            friend_id: userId,
            status: "requested",
            favorite: false
        )
        
        try await supabase
            .from("friends")
            .insert(friendRequest)
            .execute()
    }
    
    // MARK: - Accept Friend Request
    func acceptFriendRequest(from userId: String) async throws {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "UserSearchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        struct StatusUpdate: Encodable {
            let status: String
        }
        
        let updateData = StatusUpdate(status: "accepted")
        
        try await supabase
            .from("friends")
            .update(updateData)
            .eq("user_id", value: userId)
            .eq("friend_id", value: currentUserId)
            .execute()
    }
    
    // MARK: - Remove Friend
    func removeFriend(userId: String) async throws {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "UserSearchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        try await supabase
            .from("friends")
            .delete()
            .or("and(user_id.eq.\(currentUserId),friend_id.eq.\(userId)),and(user_id.eq.\(userId),friend_id.eq.\(currentUserId))")
            .execute()
    }
}
