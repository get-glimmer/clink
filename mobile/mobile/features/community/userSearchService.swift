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
    case outgoingRequested = "outgoing_requested" // I sent them a request
    case incomingRequested = "incoming_requested" // They sent me a request
    case accepted = "accepted"
    case blocked = "blocked"
    case none = "none" // No relationship exists
    
    var userStatus: UserStatus {
        switch self {
        case .outgoingRequested:
            return .requested       // Shows "Requested" — I already asked them
        case .incomingRequested:
            return .incomingRequest  // Shows "Accept" — they asked me
        case .accepted:
            return .following        // Shows "Friend"
        case .blocked, .none:
            return .canFollow        // Shows "Follow"
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
                        // Lowercase to match Postgres uuid format (avoids string comparison mismatches)
                        self.currentUserId = session.user.id.uuidString.lowercased()
                    }
                }
            } catch {
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
            // Search profiles by username OR name
            let pattern = "%\(trimmedQuery)%"
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select("*")
                .or("username.ilike.\(pattern),name.ilike.\(pattern)")
                .neq("id", value: currentUserId) // Exclude current user
                .limit(20)
                .execute()
                .value
            
            // Batch compute friendship status and mutual friend counts to avoid N+1 queries
            let targetIds = profiles.map { $0.id }
            async let statusMapAsync = getFriendshipStatusMap(for: targetIds)
            async let mutualMapAsync = getMutualFriendsCountMap(for: targetIds)
            let statusMap = await statusMapAsync
            let mutualMap = await mutualMapAsync
            
            return profiles.map { profile in
                UserSearchResult(
                    profile: profile,
                    mutualFriendsCount: mutualMap[profile.id] ?? 0,
                    friendshipStatus: statusMap[profile.id] ?? .none
                )
            }
            
        } catch {
            throw error
        }
    }
    
    // MARK: - Get Suggestions (paginated, Instagram-style)
    /// Returns a page of suggested users and whether more pages are available.
    /// - `offset`: number of pool-based suggestions already loaded (outgoing requests are always page-0 only)
    /// - `limit`: how many new suggestions to return this page (default 10)
    func getSuggestedUsers(offset: Int = 0, limit: Int = 10) async throws -> (results: [UserSearchResult], hasMore: Bool, nextOffset: Int) {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            return ([], false, offset)
        }
        
        do {
            // 1) Always need the outgoing-requested IDs so we can exclude them from the pool
            struct RequestedRow: Decodable { let friend_id: String }
            let requestedRows: [RequestedRow] = try await supabase
                .from("friends")
                .select("friend_id")
                .eq("user_id", value: currentUserId)
                .eq("status", value: "requested")
                .execute()
                .value
            let requestedIds: [String] = requestedRows.map { $0.friend_id }
            
            var suggestions: [UserSearchResult] = []
            
            // 2) On the first page, prepend outgoing-requested profiles
            if offset == 0 && !requestedIds.isEmpty {
                let requestedProfiles: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .in("id", values: requestedIds)
                    .execute()
                    .value
                
                let requestedMutuals = await getMutualFriendsCountMap(for: requestedIds)
                for profile in requestedProfiles {
                    suggestions.append(UserSearchResult(
                        profile: profile,
                        mutualFriendsCount: requestedMutuals[profile.id] ?? 0,
                        friendshipStatus: .outgoingRequested
                    ))
                }
            }
            
            // 3) Fill remaining slots from the pool (users with no existing relationship)
            let remainingCapacity = max(0, limit - suggestions.count)
            if remainingCapacity > 0 {
                // Over-fetch 3x to account for filtering out friends/blocked/requested
                let fetchSize = remainingCapacity * 3
                let poolProfiles: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .neq("id", value: currentUserId)
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + fetchSize - 1)
                    .execute()
                    .value
                
                let poolIds = poolProfiles.map { $0.id }.filter { !requestedIds.contains($0) }
                
                // Batch-fetch statuses and mutuals (2-4 queries total)
                async let statusMapAsync = getFriendshipStatusMap(for: poolIds)
                async let mutualMapAsync = getMutualFriendsCountMap(for: poolIds)
                let poolStatusMap = await statusMapAsync
                let poolMutualMap = await mutualMapAsync
                
                var candidates: [UserSearchResult] = []
                for profile in poolProfiles {
                    if requestedIds.contains(profile.id) { continue }
                    let status = poolStatusMap[profile.id] ?? .none
                    guard status == .none else { continue }
                    
                    candidates.append(UserSearchResult(
                        profile: profile,
                        mutualFriendsCount: poolMutualMap[profile.id] ?? 0,
                        friendshipStatus: .none
                    ))
                }
                
                // Sort by mutual friends and take what we need
                let fillers = candidates
                    .sorted { $0.mutualFriendsCount > $1.mutualFriendsCount }
                    .prefix(remainingCapacity)
                suggestions.append(contentsOf: fillers)

                // If the DB returned fewer rows than we asked for, there's nothing left
                let hasMore = poolProfiles.count >= fetchSize
                let nextOffset = offset + poolProfiles.count
                return (suggestions, hasMore, nextOffset)
            }

            return (suggestions, true, offset)
        } catch {
            throw error
        }
    }
    
    // MARK: - Incoming Friend Requests (users who requested to follow me)
    func getIncomingFriendRequests() async throws -> [UserProfile] {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            return []
        }
        do {
            // Find pending requests where I am the target (friend_id == me)
            struct RequestRow: Decodable { let user_id: String }
            let rows: [RequestRow] = try await supabase
                .from("friends")
                .select("user_id")
                .eq("friend_id", value: currentUserId)
                .eq("status", value: "requested")
                .execute()
                .value

            let requesterIds = rows.map { $0.user_id }
            guard !requesterIds.isEmpty else { return [] }

            // Fetch their profiles
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select("*")
                .in("id", values: requesterIds)
                .execute()
                .value
            return profiles
        } catch { return [] }
    }

    // MARK: - Friendship Status
    private func getFriendshipStatus(with userId: String) async -> FriendshipStatus {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            return .none
        }
        
        do {
            // Check relationship in BOTH directions
            let relations: [FriendRelation] = try await supabase
                .from("friends")
                .select()
                .or("and(user_id.eq.\(currentUserId),friend_id.eq.\(userId)),and(user_id.eq.\(userId),friend_id.eq.\(currentUserId))")
                .execute()
                .value

            // Prioritize accepted > requested (with direction) > blocked > none
            if relations.contains(where: { $0.status.lowercased() == "accepted" }) {
                return .accepted
            }
            // Direction matters: who sent the request?
            for rel in relations where rel.status.lowercased() == "requested" {
                if rel.user_id == currentUserId {
                    return .outgoingRequested  // I sent them a request
                } else {
                    return .incomingRequested   // They sent me a request
                }
            }
            if relations.contains(where: { $0.status.lowercased() == "blocked" }) {
                return .blocked
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
            // Fetch accepted friendships involving me in either direction
            let myRelations: [FriendRelation] = try await supabase
                .from("friends")
                .select()
                .eq("status", value: "accepted")
                .or("user_id.eq.\(currentUserId),friend_id.eq.\(currentUserId)")
                .execute()
                .value

            // Map to the other user's id regardless of direction
            let myFriendIds: Set<String> = Set(myRelations.map { rel in
                return rel.user_id == currentUserId ? rel.friend_id : rel.user_id
            })

            // Fetch accepted friendships involving the other user in either direction
            let theirRelations: [FriendRelation] = try await supabase
                .from("friends")
                .select()
                .eq("status", value: "accepted")
                .or("user_id.eq.\(userId),friend_id.eq.\(userId)")
                .execute()
                .value

            let theirFriendIds: Set<String> = Set(theirRelations.map { rel in
                return rel.user_id == userId ? rel.friend_id : rel.user_id
            })

            // Intersection size is the mutual count
            return myFriendIds.intersection(theirFriendIds).count
            
        } catch {
            return 0
        }
    }
    
    // MARK: - Bulk helpers to reduce query round-trips
    private func getFriendshipStatusMap(for targetIds: [String]) async -> [String: FriendshipStatus] {
        guard let supabase = supabase,
              let currentUserId = currentUserId,
              !targetIds.isEmpty else {
            return [:]
        }
        do {
            async let outgoingAsync: [FriendRelation] = supabase
                .from("friends")
                .select()
                .eq("user_id", value: currentUserId)
                .in("friend_id", values: targetIds)
                .execute()
                .value
            
            async let incomingAsync: [FriendRelation] = supabase
                .from("friends")
                .select()
                .eq("friend_id", value: currentUserId)
                .in("user_id", values: targetIds)
                .execute()
                .value
            
            let outgoing = try await outgoingAsync
            let incoming = try await incomingAsync
            let all = outgoing + incoming
            
            var map: [String: FriendshipStatus] = [:]
            for rel in all {
                let otherId = (rel.user_id == currentUserId) ? rel.friend_id : rel.user_id
                let statusLower = rel.status.lowercased()
                let newStatus: FriendshipStatus
                if statusLower == "accepted" {
                    newStatus = .accepted
                } else if statusLower == "requested" {
                    // Direction matters: who is the sender?
                    newStatus = (rel.user_id == currentUserId) ? .outgoingRequested : .incomingRequested
                } else if statusLower == "blocked" {
                    newStatus = .blocked
                } else { continue }
                
                // Prioritize accepted > outgoing/incoming requested > blocked
                if let existing = map[otherId] {
                    if existing == .accepted { continue }
                    if newStatus == .accepted { map[otherId] = newStatus }
                } else {
                    map[otherId] = newStatus
                }
            }
            return map
        } catch {
            return [:]
        }
    }
    
    private func getMutualFriendsCountMap(for targetIds: [String]) async -> [String: Int] {
        guard let supabase = supabase,
              let currentUserId = currentUserId,
              !targetIds.isEmpty else {
            return [:]
        }
        do {
            // My accepted friends (both directions), in parallel
            async let myOutgoingAsync: [FriendRelation] = supabase
                .from("friends")
                .select()
                .eq("status", value: "accepted")
                .eq("user_id", value: currentUserId)
                .execute()
                .value
            async let myIncomingAsync: [FriendRelation] = supabase
                .from("friends")
                .select()
                .eq("status", value: "accepted")
                .eq("friend_id", value: currentUserId)
                .execute()
                .value
            
            // Accepted relations involving any of the target users, in parallel
            async let targetOutgoingAsync: [FriendRelation] = supabase
                .from("friends")
                .select()
                .eq("status", value: "accepted")
                .in("user_id", values: targetIds)
                .execute()
                .value
            async let targetIncomingAsync: [FriendRelation] = supabase
                .from("friends")
                .select()
                .eq("status", value: "accepted")
                .in("friend_id", values: targetIds)
                .execute()
                .value
            
            let (myOutgoing, myIncoming, targetOutgoing, targetIncoming) = try await (myOutgoingAsync, myIncomingAsync, targetOutgoingAsync, targetIncomingAsync)
            
            var myFriendIds: Set<String> = Set(myOutgoing.map { $0.friend_id })
            myFriendIds.formUnion(myIncoming.map { $0.user_id })
            
            // Build map of each target's accepted friends
            var targetFriendIdsMap: [String: Set<String>] = [:]
            for rel in targetOutgoing {
                targetFriendIdsMap[rel.user_id, default: []].insert(rel.friend_id)
            }
            for rel in targetIncoming {
                targetFriendIdsMap[rel.friend_id, default: []].insert(rel.user_id)
            }
            
            var counts: [String: Int] = [:]
            for id in targetIds {
                let theirSet = targetFriendIdsMap[id] ?? []
                counts[id] = myFriendIds.intersection(theirSet).count
            }
            return counts
        } catch {
            return [:]
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
    
    // MARK: - Decline Friend Request (delete pending relation)
    func declineFriendRequest(from userId: String) async throws {
        try await removeFriend(userId: userId)
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
