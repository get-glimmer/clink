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
    private var supabase: SupabaseClient? {
        return SupabaseClientManager.shared.client
    }
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
            
            // Sort friends: favorites first, then alphabetically by name
            return friends.sorted { first, second in
                if first.isFavorite != second.isFavorite {
                    return first.isFavorite && !second.isFavorite
                }
                return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            }
            
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
    
    // MARK: - Likes Functions
    
    /// Check if user has liked a specific category
    func isLiked(categoryId: UUID, userId: UUID) async throws -> Bool {
        guard let supabase = supabase else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"])
        }
        
        do {
            let response = try await supabase.database
                .from("likes")
                .select("like_id")
                .eq("user_id", value: userId)
                .eq("category_id", value: categoryId)
                .execute()
            
            let data = response.data
            
            // Try to decode as LikeRecord array
            do {
                let decoder = JSONDecoder()
                let likes = try decoder.decode([LikeRecord].self, from: data)
                return !likes.isEmpty
            } catch {
                // Fallback: Check if response data contains any records
                if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    return !jsonArray.isEmpty
                } else {
                    return false
                }
            }
        } catch {
            throw error
        }
    }
    
    /// Like a category
    func likeCategory(categoryId: UUID, userId: UUID) async throws {
        guard let supabase = supabase else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"])
        }
        
        // First check if already liked to avoid duplicates
        let alreadyLiked = try await isLiked(categoryId: categoryId, userId: userId)
        if alreadyLiked {
            return // Already liked, do nothing
        }
        
        let likeData = [
            "user_id": userId.uuidString,
            "category_id": categoryId.uuidString
        ]
        
        let _ = try await supabase.database
            .from("likes")
            .insert(likeData)
            .execute()
    }
    
    /// Unlike a category
    func unlikeCategory(categoryId: UUID, userId: UUID) async throws {
        guard let supabase = supabase else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"])
        }
        
        let _ = try await supabase.database
            .from("likes")
            .delete()
            .eq("user_id", value: userId)
            .eq("category_id", value: categoryId)
            .execute()
    }
    
    /// Get like count for a category
    func getLikeCount(categoryId: UUID) async throws -> Int {
        guard let supabase = supabase else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"])
        }
        
        let response = try await supabase.database
            .from("likes")
            .select("like_id")
            .eq("category_id", value: categoryId)
            .execute()
        
        let data = response.data
        let decoder = JSONDecoder()
        let likes = try decoder.decode([LikeRecord].self, from: data)
        
        return likes.count
    }
    
    // MARK: - Notes Functions
    
    /// Get friend's current shaker ID for today
    func getCurrentShakerForUser(userId: String, date: Date = Date()) async throws -> UUID? {
        guard let supabase = supabase else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"])
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        let response = try await supabase.database
            .from("shaker")
            .select("id")
            .eq("userid", value: userId)
            .eq("date", value: dateString)
            .limit(1)
            .execute()
        
        let data = response.data
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let firstRecord = jsonArray.first,
           let idString = firstRecord["id"] as? String,
           let shakerId = UUID(uuidString: idString) {
            return shakerId
        }
        
        return nil
    }
    
    /// Submit a note to a friend's shaker
    func submitNote(to shakerId: UUID, content: String, fromUserId: UUID) async throws {
        guard let supabase = supabase else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"])
        }
        
        // TODO: Add offensive language check here
        // let hasOffensiveContent = await containsOffensiveLanguage(content)
        // if hasOffensiveContent { throw OffensiveLanguageError() }
        
        let noteData = [
            "user_id": fromUserId.uuidString,
            "shaker_id": shakerId.uuidString,
            "note_content": content
        ]
        
        let _ = try await supabase.database
            .from("notes")
            .insert(noteData)
            .execute()
    }
    
    /// Get random notes for a specific shaker
    func getNotesForShaker(shakerId: UUID, limit: Int = 10) async throws -> [NoteRecord] {
        guard let supabase = supabase else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"])
        }
        
        let response = try await supabase.database
            .from("notes")
            .select("note_id, user_id, note_content, created_at")
            .eq("shaker_id", value: shakerId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
        
        let data = response.data
        let decoder = JSONDecoder()
        
        // Set up date decoding for Supabase timestamp format
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // Fallback formatters for different timestamp formats
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // PostgreSQL default format (no Z, with timezone offset)
        let postgresFormatter = DateFormatter()
        postgresFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS+00:00"
        postgresFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            // Try primary format first (with microseconds)
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try fallback format (without microseconds)
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }
            
            // Try PostgreSQL format
            if let date = postgresFormatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 as last resort
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date from: \(dateString)")
        }
        
        return try decoder.decode([NoteRecord].self, from: data)
    }
    
    // Note: We intentionally do not persist note emoji into category_emojis.
}

// MARK: - Like Models
struct LikeRecord: Codable {
    let likeId: UUID
    
    enum CodingKeys: String, CodingKey {
        case likeId = "like_id"
    }
}

// MARK: - Note Models
struct NoteRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let noteContent: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "note_id"
        case userId = "user_id"
        case noteContent = "note_content"
        case createdAt = "created_at"
    }
}
