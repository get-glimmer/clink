//
//  searchView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI

struct SearchUser: Identifiable {
    let id = UUID()
    let actualUserId: String // Add the actual database user ID
    let username: String
    let profileImageName: String
    let mutualFriends: Int?
    let status: UserStatus
}

enum UserStatus {
    case canFollow
    case requested
    case following
    
    var displayText: String {
        switch self {
        case .canFollow:
            return "Follow"
        case .requested:
            return "Requested"
        case .following:
            return "Following"
        }
    }
    
    var textColor: Color {
        switch self {
        case .canFollow:
            return AppColors.textWhite
        case .requested:
            return AppColors.neutral400
        case .following:
            return AppColors.neutral400
        }
    }
}

struct SearchView: View {
    @State private var searchText: String = ""
    @State private var searchResults: [SearchUser] = []
    @State private var suggestions: [SearchUser] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @StateObject private var searchService = UserSearchService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search Header
                searchHeader
                
                // Search Results
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Loading indicator
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.textWhite))
                                Text("Searching...")
                                    .foregroundColor(AppColors.textWhite)
                                    .font(.system(size: 16))
                            }
                            .padding(.top, 40)
                        }
                        
                        // Error message
                        else if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(Color.red)
                                .font(.system(size: 16))
                                .padding(.horizontal, 20)
                                .padding(.top, 40)
                        }
                        
                        // Direct search results
                        else if !searchResults.isEmpty {
                            ForEach(searchResults) { user in
                                UserRowView(user: user, searchService: searchService)
                            }
                        }
                        
                        // Empty search state
                        else if !searchText.isEmpty && searchResults.isEmpty && !isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.slash")
                                    .foregroundColor(AppColors.neutral400)
                                    .font(.system(size: 40))
                                Text("No users found")
                                    .foregroundColor(AppColors.neutral400)
                                    .font(.system(size: 18, weight: .medium))
                                Text("Try searching with a different username or name")
                                    .foregroundColor(AppColors.neutral500)
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 60)
                        }
                        
                        // Suggestions section
                        if !suggestions.isEmpty && searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Suggestion")
                                        .foregroundColor(AppColors.textWhite)
                                        .font(.system(size: 18, weight: .medium))
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 30)
                                .padding(.bottom, 15)
                                
                                ForEach(suggestions) { user in
                                    UserRowView(user: user, searchService: searchService)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .onAppear {
            // Only load suggestions if we have a current user
            // Wait a bit for authentication to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadSuggestions()
            }
        }
    }
    
    private var searchHeader: some View {
        HStack(spacing: 15) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.neutral400)
                    .font(.system(size: 16))
                
                TextField("Search users...", text: $searchText)
                    .foregroundColor(AppColors.textWhite)
                    .font(.system(size: 16))
                    .onChange(of: searchText) { oldValue, newValue in
                        Task {
                            await performSearch()
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.neutral900)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.blue, lineWidth: 2)
            )
            
            // Close Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(AppColors.textWhite)
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private func loadSuggestions() {
        Task {
            do {
                isLoading = true
                errorMessage = nil
                
                // Add a small delay to ensure authentication is complete
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                let suggestedUsers = try await searchService.getSuggestedUsers()
                
                await MainActor.run {
                    self.suggestions = suggestedUsers.map { $0.toSearchUser() }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load suggestions: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        do {
            isLoading = true
            errorMessage = nil
            
            let userResults = try await searchService.searchUsers(query: searchText)
            
            await MainActor.run {
                self.searchResults = userResults.map { $0.toSearchUser() }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.searchResults = []
                self.isLoading = false
            }
        }
    }
}

struct UserRowView: View {
    let user: SearchUser
    let searchService: UserSearchService
    @State private var isActionLoading = false
    @State private var currentStatus: UserStatus
    
    init(user: SearchUser, searchService: UserSearchService) {
        self.user = user
        self.searchService = searchService
        self._currentStatus = State(initialValue: user.status)
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile Image
            Image(user.profileImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .foregroundColor(AppColors.textWhite)
                    .font(.system(size: 16, weight: .medium))
                
                if let mutualFriends = user.mutualFriends {
                    Text("\(mutualFriends) Mutuals")
                        .foregroundColor(AppColors.neutral400)
                        .font(.system(size: 14))
                }
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                Task {
                    await handleUserAction()
                }
            }) {
                HStack(spacing: 4) {
                    if isActionLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: currentStatus.textColor))
                            .scaleEffect(0.8)
                    } else {
                        Text(currentStatus.displayText)
                            .foregroundColor(currentStatus.textColor)
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .frame(minWidth: 80)
            }
            .disabled(isActionLoading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func handleUserAction() async {
        isActionLoading = true
        
        do {
            switch currentStatus {
            case .canFollow:
                // Send friend request
                try await searchService.sendFriendRequest(to: user.actualUserId)
                await MainActor.run {
                    currentStatus = .requested
                }
                
            case .requested:
                // Cancel friend request (remove the pending request)
                try await searchService.removeFriend(userId: user.actualUserId)
                await MainActor.run {
                    currentStatus = .canFollow
                }
                
            case .following:
                // Unfollow/Remove friend (remove the accepted friendship)
                try await searchService.removeFriend(userId: user.actualUserId)
                await MainActor.run {
                    currentStatus = .canFollow
                }
            }
            
        } catch {
            print("Error handling user action: \(error)")
            // Don't change status on error - let user try again
        }
        
        await MainActor.run {
            isActionLoading = false
        }
    }
}

#Preview {
    SearchView()
}