//
//  communityViewModel.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI
import Supabase

class CommunityViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var selectedCategory: String = "Friends"
    @Published var selectedFriendId: UUID? = nil
    @Published var showingDropdown: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    let categories = ["Friends", "Favorites", "All"]
    private let communityService = CommunityService()
    
    init() {
        loadFriendsData(refresh: false)
    }
    
    private func loadFriendsData(refresh: Bool) {
        Task {
            await MainActor.run {
                if !refresh { self.isLoading = true }
                self.errorMessage = nil
            }
            
            do {
                let fetchedFriends = try await communityService.getFriendsByCategory(selectedCategory)
                
                await MainActor.run {
                    self.friends = fetchedFriends
                    self.isLoading = false
                    
                    // If no friend is selected and we have friends, select the first one
                    if self.selectedFriendId == nil && !fetchedFriends.isEmpty {
                        self.selectedFriendId = fetchedFriends.first?.id
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load friends: \(error.localizedDescription)"
                    self.isLoading = false
                    // Fallback to sample data if database fails
                    self.loadSampleData()
                }
            }
        }
    }
    
    private func loadSampleData() {
        friends = [
            Friend(
                userId: "sample-nikki-id",
                name: "Nikki",
                profileImageName: "nav-profile1x",
                progress: 0.85,
                emojis: ["☃️", "❄️", "🧤", "🎿", "⛄"],
                isSelected: false,
                isFavorite: true
            ),
            Friend(
                userId: "sample-jeremie-id",
                name: "Jeremie",
                profileImageName: "nav-profile1x",
                progress: 0.92,
                emojis: ["🎨", "🖌️", "🎭", "🌟", "🎪", "🎯"],
                isSelected: false,
                isFavorite: false
            ),
            Friend(
                userId: "sample-eunsoo-id",
                name: "Eunsoo",
                profileImageName: "nav-profile1x",
                progress: 0.78,
                emojis: ["🌸", "🌺", "🌻", "🌷", "🌹", "💐"],
                isSelected: false,
                isFavorite: true
            ),
            Friend(
                userId: "sample-fiona-id",
                name: "Fiona",
                profileImageName: "nav-profile1x",
                progress: 0.45,
                emojis: ["🍎", "🍊", "🎂", "⭐", "💕"],
                isSelected: true,
                isFavorite: false
            )
        ]
        
        // Set the selected friend ID for Fiona
        if let fiona = friends.first(where: { $0.name == "Fiona" }) {
            selectedFriendId = fiona.id
        }
    }
    
    func selectFriend(_ friend: Friend) {
        selectedFriendId = friend.id
        // Update friends array to reflect selection
        friends = friends.map { currentFriend in
            Friend(
                userId: currentFriend.userId,
                name: currentFriend.name,
                profileImageName: currentFriend.profileImageName,
                progress: currentFriend.progress,
                emojis: currentFriend.emojis,
                isSelected: currentFriend.id == friend.id,
                isFavorite: currentFriend.isFavorite
            )
        }
    }
    
    func selectCategory(_ category: String) {
        selectedCategory = category
        showingDropdown = false
        // Reload friends data for the new category
        loadFriendsData(refresh: false)
    }
    
    func toggleDropdown() {
        showingDropdown.toggle()
    }
    
    // MARK: - Friend Actions
    func unfollowFriend(named friendName: String) {
        Task {
            do {
                try await communityService.unfollowFriend(withName: friendName)
                
                // Reload friends data to reflect the change
                await MainActor.run {
                    self.loadFriendsData(refresh: false)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to unfollow friend: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func addFriendToFavorites(named friendName: String) {
        Task {
            do {
                try await communityService.addToFavorites(friendName: friendName)
                
                // Reload friends data to reflect the change
                await MainActor.run {
                    self.loadFriendsData(refresh: false)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to add to favorites: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func removeFriendFromFavorites(named friendName: String) {
        Task {
            do {
                try await communityService.removeFromFavorites(friendName: friendName)
                
                // Reload friends data to reflect the change
                await MainActor.run {
                    self.loadFriendsData(refresh: false)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to remove from favorites: \(error.localizedDescription)"
                }
            }
        }
    }

    // ID-based variants used when we already have Friend.userId
    func addFriendToFavoritesById(friendId: String) {
        Task {
            do {
                try await communityService.addToFavorites(friendId: friendId)
                await MainActor.run { self.loadFriendsData(refresh: false) }
            } catch {
                await MainActor.run { self.errorMessage = "Failed to add to favorites: \(error.localizedDescription)" }
            }
        }
    }

    func removeFriendFromFavoritesById(friendId: String) {
        Task {
            do {
                try await communityService.removeFromFavorites(friendId: friendId)
                await MainActor.run { self.loadFriendsData(refresh: false) }
            } catch {
                await MainActor.run { self.errorMessage = "Failed to remove from favorites: \(error.localizedDescription)" }
            }
        }
    }
    
    func refreshFriends() {
        loadFriendsData(refresh: true)
    }

    // Realtime V2 pending: placeholder removed to avoid build errors
}