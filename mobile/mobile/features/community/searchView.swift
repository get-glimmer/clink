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
    @State private var incomingRequests: [UserProfile] = []
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
                        // Incoming friend requests (above suggestions)
                        if !incomingRequests.isEmpty && searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Friend Requests")
                                    .foregroundColor(AppColors.neutral300)
                                    .appFont(AppFont.labelS)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 24)
                                    .padding(.bottom, 14)

                                ForEach(incomingRequests, id: \.id) { profile in
                                    FriendRequestRow(profile: profile, searchService: searchService, onResponded: {
                                        Task { await loadIncomingRequests() }
                                    })
                                }
                            }
                        }
                        // Loading indicator
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.textWhite))
                                Text("Searching...")
                                    .foregroundColor(AppColors.neutral300)
                                    .appFont(AppFont.labelM)
                            }
                            .padding(.top, 40)
                        }
                        
                        // Error message
                        else if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(Color.red)
                                .appFont(AppFont.labelL)
                                .padding(.horizontal, 16)
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
                                    .appFont(AppFont.labelL)
                                Text("Try searching with a different username or name")
                                    .foregroundColor(AppColors.neutral500)
                                    .appFont(AppFont.labelM)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 60)
                        }
                        
                        // Suggestions section
                        if !suggestions.isEmpty && searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Suggestion")
                                        .foregroundColor(AppColors.neutral300)
                                        .appFont(AppFont.labelS)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
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
                Task { await loadIncomingRequests() }
            }
        }
    }
    
    private var searchHeader: some View {
        HStack(spacing: 8) {
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.neutral400)
                    .font(.system(size: 16))
                
                TextField("Search users...", text: $searchText)
                    .foregroundColor(AppColors.neutral600)
                    .appFont(AppFont.body1)
                    .onChange(of: searchText) { oldValue, newValue in
                        Task {
                            await performSearch()
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.neutral900)
            .cornerRadius(22)
            .frame(width: 318, height: 44)
            
            // Close Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(AppColors.neutral400)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(AppColors.neutral900)
                    )
            }
        }
        .padding(.horizontal, 16)
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

    private func loadIncomingRequests() async {
        do {
            let requests = try await searchService.getIncomingFriendRequests()
            await MainActor.run { self.incomingRequests = requests }
        } catch {
            await MainActor.run { self.incomingRequests = [] }
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
            // Profile Image (URL-aware with fallback, consistent with CommunityView)
            avatarView()
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .foregroundColor(AppColors.textWhite)
                    .appFont(AppFont.labelM)
                
                if let mutualFriends = user.mutualFriends {
                    Text("\(mutualFriends) Mutuals")
                        .foregroundColor(AppColors.neutral400)
                        .appFont(AppFont.captionXS_M)
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
                            .appFont(AppFont.buttonM)
                    }
                }
                .frame(minWidth: 80, alignment: .trailing)
            }
            .disabled(isActionLoading)
        }
        .padding(.horizontal, 16)
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

    // MARK: - Avatar helper (matches FriendCardView logic)
    @ViewBuilder
    private func avatarView() -> some View {
        let size: CGFloat = 40
        let glyphSize: CGFloat = size * 0.62
        // Fallback avatar: gray circle + profile glyph + stroke
        let fallbackAvatar = AnyView(
            ZStack {
                Circle()
                    .fill(AppColors.neutral800)
                Image("profile")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(AppColors.textWhite)
                    .frame(width: glyphSize, height: glyphSize)
                Circle()
                    .stroke(AppColors.neutral700, lineWidth: 1)
            }
            .frame(width: size, height: size)
        )

        if let url = URL(string: user.profileImageName), user.profileImageName.lowercased().hasPrefix("http") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    fallbackAvatar
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    fallbackAvatar
                @unknown default:
                    fallbackAvatar
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallbackAvatar
                .clipShape(Circle())
        }
    }
}

// MARK: - Friend Request Row
struct FriendRequestRow: View {
    let profile: UserProfile
    let searchService: UserSearchService
    var onResponded: () -> Void
    @State private var isWorking = false

    var body: some View {
        HStack(spacing: 15) {
            // Match 40x40 avatar size
            Image(profile.avatar_url ?? "nav-profile1x")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name ?? profile.username ?? "Unknown")
                    .foregroundColor(AppColors.textWhite)
                    .appFont(AppFont.labelM)
            }
            Spacer()

            Button(action: { Task { await decline() } }) {
                Text("Decline")
                    .foregroundColor(AppColors.textWhite)
                    .appFont(AppFont.buttonM)
            }
            .disabled(isWorking)

            Button(action: { Task { await accept() } }) {
                Text("Accept")
                    .foregroundColor(.black)
                    .appFont(AppFont.labelS)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.green300)
                    .cornerRadius(4)
            }
            .disabled(isWorking)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func accept() async {
        isWorking = true
        do {
            try await searchService.acceptFriendRequest(from: profile.id)
            await MainActor.run {
                isWorking = false
                onResponded()
                NotificationCenter.default.post(name: .friendRequestsChanged, object: nil)
            }
        } catch {
            await MainActor.run { isWorking = false }
        }
    }

    private func decline() async {
        isWorking = true
        do {
            try await searchService.declineFriendRequest(from: profile.id)
            await MainActor.run {
                isWorking = false
                onResponded()
                NotificationCenter.default.post(name: .friendRequestsChanged, object: nil)
            }
        } catch {
            await MainActor.run { isWorking = false }
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let friendRequestsChanged = Notification.Name("friendRequestsChanged")
}

#Preview {
    SearchView()
}
