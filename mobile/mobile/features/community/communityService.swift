//
//  communityService.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import Foundation
import Supabase

// MARK: - Database Models for Community
struct FriendProfile: Codable, Identifiable {
    let id: String
    let name: String?
    let username: String?
    let avatar_url: String?
    let bio: String?
    let email: String?
    let created_at: String?
}

struct FriendshipData: Codable {
    let user_id: String
    let friend_id: String
    let status: String
    let favorite: Bool?
    let created_at: String?
    let updated_at: String?
}

struct TaskProgressData: Codable {
    let userid: String
    let categoryid: String?
    let iscompleted: Bool
    let createdat: String?
    let category_emojis: [String]?
}

// MARK: - Community Service
class CommunityService: ObservableObject {
    private let supabase = SupabaseClientManager.shared.client
    @Published private(set) var isInitialized = false
    private var currentUserId: String?
    
    init() {
        Task {
            await initializeService()
        }
    }
    
    private func initializeService() async {
        do {
            if let session = try await supabase?.auth.session {
                self.currentUserId = session.user.id.uuidString
                await MainActor.run {
                    self.isInitialized = true
                }
            }
        } catch {
            print("Error initializing community service: \(error)")
        }
    }
    
    // MARK: - Get Friends with Progress Data
    func getFriendsWithProgress() async throws -> [Friend] {
        // Wait for initialization if not already initialized
        if !isInitialized {
            await initializeService()
        }
        
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "CommunityService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service not properly initialized"])
        }
        
        do {
            // Get accepted friends (exclude blocked)
            let friendships: [FriendshipData] = try await supabase
                .from("friends")
                .select("*")
                .eq("user_id", value: currentUserId)
                .eq("status", value: "accepted")
                .neq("status", value: "blocked")  // Exclude blocked friends
                .execute()
                .value
            
            let friendIds = friendships.map { $0.friend_id }
            
            guard !friendIds.isEmpty else {
                return []
            }
            
            // Get friend profiles
            let friendProfiles: [FriendProfile] = try await supabase
                .from("profiles")
                .select("*")
                .in("id", value: friendIds)
                .execute()
                .value
            
            // Create a mapping of friend IDs to favorite status
            let favoriteMapping = Dictionary(uniqueKeysWithValues: friendships.map { ($0.friend_id, $0.favorite ?? false) })
            
            // Get task progress for each friend
            var friends: [Friend] = []
            
            for profile in friendProfiles {
                let progress = await getTaskProgress(for: profile.id)
                let emojis = await getCategoryEmojis(for: profile.id)
                let isFavorite = favoriteMapping[profile.id] ?? false
                
                let friend = Friend(
                    userId: profile.id,
                    name: profile.name ?? profile.username ?? "Unknown",
                    profileImageName: profile.avatar_url ?? "nav-profile1x",
                    progress: progress,
                    emojis: emojis,
                    isSelected: false,
                    isFavorite: isFavorite
                )
                friends.append(friend)
            }
            
            return friends
            
        } catch {
            print("Error fetching friends: \(error)")
            throw error
        }
    }
    
    // MARK: - Get Task Progress for User
    private func getTaskProgress(for userId: String) async -> Double {
        guard let supabase = supabase else { return 0.0 }
        
        do {
            // Get today's date
            let today = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayString = formatter.string(from: today)
            
            // Get total tasks for today
            let totalTasks: [TaskProgressData] = try await supabase
                .from("task")
                .select("*")
                .eq("userid", value: userId)
                .gte("createdat", value: todayString)
                .execute()
                .value
            
            guard !totalTasks.isEmpty else { return 0.0 }
            
            // Get completed tasks for today
            let completedTasks = totalTasks.filter { $0.iscompleted }
            
            // Calculate progress percentage
            let progress = Double(completedTasks.count) / Double(totalTasks.count)
            return min(max(progress, 0.0), 1.0) // Clamp between 0 and 1
            
        } catch {
            print("Error fetching task progress for user \(userId): \(error)")
            return 0.0
        }
    }
    
    // MARK: - Get Category Emojis for User
    private func getCategoryEmojis(for userId: String) async -> [String] {
        guard let supabase = supabase else { return [] }
        
        do {
            // Get today's shaker data which contains category emojis
            let today = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayString = formatter.string(from: today)
            
            struct ShakerResponse: Codable {
                let category_emojis: [String]?
            }
            
            let shakers: [ShakerResponse] = try await supabase
                .from("shaker")
                .select("category_emojis")
                .eq("userid", value: userId)
                .eq("date", value: todayString)
                .execute()
                .value
            
            // Extract category emojis from the first shaker record
            if let firstShaker = shakers.first,
               let categoryEmojis = firstShaker.category_emojis {
                return Array(categoryEmojis.prefix(8)) // Limit to 8 emojis for display
            }
            
            return []
            
        } catch {
            print("Error fetching category emojis for user \(userId): \(error)")
            return []
        }
    }
    
    // MARK: - Get Filtered Friends by Category
    func getFriendsByCategory(_ category: String) async throws -> [Friend] {
        let allFriends = try await getFriendsWithProgress()
        
        switch category {
        case "Friends":
            return allFriends
        case "Favorites":
            return allFriends.filter { $0.isFavorite }
        case "All":
            return allFriends
        default:
            return allFriends
        }
    }
    
    // MARK: - Unfollow Friend
    func unfollowFriend(withName name: String) async throws {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "CommunityService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        do {
            // Find the friend's profile by name
            let profiles: [FriendProfile] = try await supabase
                .from("profiles")
                .select("*")
                .eq("name", value: name)
                .execute()
                .value
            
            guard let friendProfile = profiles.first else {
                throw NSError(domain: "CommunityService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Friend not found"])
            }
            
            // Update friendship status to blocked
            struct FriendshipUpdate: Encodable {
                let status: String
                let updated_at: String
            }
            
            let updateData = FriendshipUpdate(
                status: "blocked",
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabase
                .from("friends")
                .update(updateData)
                .eq("user_id", value: currentUserId)
                .eq("friend_id", value: friendProfile.id)
                .execute()
            
        } catch {
            print("Error unfollowing friend: \(error)")
            throw error
        }
    }
    
    // MARK: - Add to Favorites
    func addToFavorites(friendName: String) async throws {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "CommunityService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        do {
            // Find the friend's profile by name
            let profiles: [FriendProfile] = try await supabase
                .from("profiles")
                .select("*")
                .eq("name", value: friendName)
                .execute()
                .value
            
            guard let friendProfile = profiles.first else {
                throw NSError(domain: "CommunityService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Friend not found"])
            }
            
            // Update friendship favorite status
            struct FavoriteUpdate: Encodable {
                let favorite: Bool
                let updated_at: String
            }
            
            let updateData = FavoriteUpdate(
                favorite: true,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabase
                .from("friends")
                .update(updateData)
                .eq("user_id", value: currentUserId)
                .eq("friend_id", value: friendProfile.id)
                .execute()
            
        } catch {
            print("Error adding friend to favorites: \(error)")
            throw error
        }
    }
    
    // MARK: - Remove from Favorites
    func removeFromFavorites(friendName: String) async throws {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "CommunityService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        do {
            // Find the friend's profile by name
            let profiles: [FriendProfile] = try await supabase
                .from("profiles")
                .select("*")
                .eq("name", value: friendName)
                .execute()
                .value
            
            guard let friendProfile = profiles.first else {
                throw NSError(domain: "CommunityService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Friend not found"])
            }
            
            // Update friendship favorite status
            struct FavoriteUpdate: Encodable {
                let favorite: Bool
                let updated_at: String
            }
            
            let updateData = FavoriteUpdate(
                favorite: false,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabase
                .from("friends")
                .update(updateData)
                .eq("user_id", value: currentUserId)
                .eq("friend_id", value: friendProfile.id)
                .execute()
            
        } catch {
            print("Error removing friend from favorites: \(error)")
            throw error
        }
    }
    
    // MARK: - Friend Request Management
    func acceptFriendRequest(from userId: String) async throws {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "CommunityService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        do {
            // Update the friend request status to accepted
            struct AcceptUpdate: Encodable {
                let status: String
                let updated_at: String
            }
            
            let updateData = AcceptUpdate(
                status: "accepted",
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabase
                .from("friends")
                .update(updateData)
                .eq("user_id", value: userId)
                .eq("friend_id", value: currentUserId)
                .eq("status", value: "requested")
                .execute()
            
        } catch {
            print("Error accepting friend request: \(error)")
            throw error
        }
    }
    
    // MARK: - Get Pending Friend Requests
    func getPendingFriendRequests() async throws -> [Friend] {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "CommunityService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service not properly initialized"])
        }
        
        do {
            // Get pending friend requests sent to me
            let pendingRequests: [FriendshipData] = try await supabase
                .from("friends")
                .select("*")
                .eq("friend_id", value: currentUserId)
                .eq("status", value: "requested")
                .execute()
                .value
            
            let requesterIds = pendingRequests.map { $0.user_id }
            
            guard !requesterIds.isEmpty else {
                return []
            }
            
            // Get profiles of users who sent requests
            let requesterProfiles: [FriendProfile] = try await supabase
                .from("profiles")
                .select("*")
                .in("id", value: requesterIds)
                .execute()
                .value
            
            // Convert to Friend objects
            var friendRequests: [Friend] = []
            
            for profile in requesterProfiles {
                let progress = await getTaskProgress(for: profile.id)
                let emojis = await getCategoryEmojis(for: profile.id)
                
                let friend = Friend(
                    userId: profile.id,
                    name: profile.name ?? profile.username ?? "Unknown",
                    profileImageName: profile.avatar_url ?? "nav-profile1x",
                    progress: progress,
                    emojis: emojis,
                    isSelected: false,
                    isFavorite: false // New requests are not favorites by default
                )
                friendRequests.append(friend)
            }
            
            return friendRequests
            
        } catch {
            print("Error fetching pending friend requests: \(error)")
            throw error
        }
    }
    
    // MARK: - Fetch Friend's Tasks with Privacy Filtering
    func getFriendTasks(friendId: String, date: Date) async throws -> [CategoryWithTasks] {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "CommunityService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service not properly initialized"])
        }
        
        // Format date for database query
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        do {
            // First, fetch friend's categories with privacy filtering
            let categories: [CategoryItem] = try await supabase
                .from("category")
                .select("*")
                .eq("userid", value: friendId)
                .in("privacy_status", value: ["public", "friends_only"]) // Exclude user_only
                .execute()
                .value
            
            var categoriesWithTasks: [CategoryWithTasks] = []
            
            // For each category, fetch its tasks for the specified date
            for category in categories {
                let tasks: [TaskListItem] = try await supabase
                    .from("task")
                    .select("*")
                    .eq("userid", value: friendId)
                    .eq("categoryid", value: category.id.uuidString)
                    .gte("createdat", value: dateString)
                    .lt("createdat", value: dateString + " 23:59:59")
                    .execute()
                    .value
                
                // Only include categories that have tasks for this date or are public
                if !tasks.isEmpty {
                    let categoryWithTasks = CategoryWithTasks(
                        id: category.id,
                        category: category,
                        tasks: tasks
                    )
                    categoriesWithTasks.append(categoryWithTasks)
                }
            }
            
            return categoriesWithTasks
            
        } catch {
            print("Error fetching friend's tasks: \(error)")
            throw error
        }
    }
}
