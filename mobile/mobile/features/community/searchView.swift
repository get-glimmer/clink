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
    case requested       // I sent them a request
    case incomingRequest // They sent me a request
    case following
    
    var displayText: String {
        switch self {
        case .canFollow:
            return "Follow"
        case .requested:
            return "Requested"
        case .incomingRequest:
            return "Accept"
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
        case .incomingRequest:
            return AppColors.green300
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
    
    // Pagination state for suggestions
    @State private var suggestionOffset: Int = 0
    @State private var hasMoreSuggestions: Bool = true
    @State private var isLoadingMore: Bool = false
    private let pageSize = 10
    
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
                                    .appFont(AppFont.labelM)
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
                                        .appFont(AppFont.labelM)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 30)
                                .padding(.bottom, 15)
                                
                                ForEach(suggestions) { user in
                                    UserRowView(user: user, searchService: searchService)
                                        .onAppear {
                                            // Trigger next page when the last item becomes visible
                                            if user.id == suggestions.last?.id {
                                                loadMoreSuggestions()
                                            }
                                        }
                                }
                                
                                if isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.neutral400))
                                            .padding(.vertical, 16)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .onAppear {
            loadSuggestions()
            Task { await loadIncomingRequests() }
        }
    }
    
    private var searchHeader: some View {
        HStack(spacing: 8) {
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.neutral400)
                    .font(.system(size: 16))
                
                TextField("Search username..", text: $searchText)
                    .foregroundColor(AppColors.neutral600)
                    .appFont(AppFont.body1)
                    .onChange(of: searchText) { oldValue, newValue in
                        // Debounce input to reduce network calls
                        debounceSearch()
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
    
    @State private var debounceTask: Task<Void, Never>?
    
    private func debounceSearch() {
        debounceTask?.cancel()
        let currentQuery = searchText
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            if !Task.isCancelled, currentQuery == searchText {
                await performSearch()
            }
        }
    }
    
    private func loadSuggestions() {
        Task {
            do {
                isLoading = true
                errorMessage = nil
                
                let (suggestedUsers, hasMore) = try await searchService.getSuggestedUsers(offset: 0, limit: pageSize)
                
                await MainActor.run {
                    self.suggestions = suggestedUsers.map { $0.toSearchUser() }
                    self.suggestionOffset = suggestedUsers.count
                    self.hasMoreSuggestions = hasMore
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
    
    private func loadMoreSuggestions() {
        guard !isLoadingMore, hasMoreSuggestions else { return }
        isLoadingMore = true
        
        Task {
            do {
                let (moreUsers, hasMore) = try await searchService.getSuggestedUsers(offset: suggestionOffset, limit: pageSize)
                
                await MainActor.run {
                    let newItems = moreUsers.map { $0.toSearchUser() }
                    self.suggestions.append(contentsOf: newItems)
                    self.suggestionOffset += moreUsers.count
                    self.hasMoreSuggestions = hasMore && !moreUsers.isEmpty
                    self.isLoadingMore = false
                }
            } catch {
                await MainActor.run {
                    self.hasMoreSuggestions = false
                    self.isLoadingMore = false
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
            AvatarView(imageURLOrName: user.profileImageName, size: 40)
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 10) {
                    Text(user.username)
                        .foregroundColor(AppColors.textWhite)
                        .appFont(AppFont.labelM)
                    if let mutualFriends = user.mutualFriends {
                        Text("\(mutualFriends) Mutuals")
                            .foregroundColor(AppColors.neutral300)
                            .appFont(AppFont.captionXS_M)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.neutral900)
                            .cornerRadius(8)
                }
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
            .padding(.trailing, 10)
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
                // Cancel my outgoing friend request
                try await searchService.removeFriend(userId: user.actualUserId)
                await MainActor.run {
                    currentStatus = .canFollow
                }

            case .incomingRequest:
                // Accept their incoming friend request
                try await searchService.acceptFriendRequest(from: user.actualUserId)
                await MainActor.run {
                    currentStatus = .following
                    NotificationCenter.default.post(name: .friendRequestsChanged, object: nil)
                }
                
            case .following:
                // Unfollow/Remove friend
                try await searchService.removeFriend(userId: user.actualUserId)
                await MainActor.run {
                    currentStatus = .canFollow
                }
            }
            
        } catch {
        }
        
        await MainActor.run {
            isActionLoading = false
        }
    }

    // Removed duplicate local avatar helper (use shared AvatarView)
}

// MARK: - Friend Request Row
struct FriendRequestRow: View {
    let profile: UserProfile
    let searchService: UserSearchService
    var onResponded: () -> Void
    @State private var isWorking = false

    var body: some View {
        HStack(spacing: 15) {
            // Match 40x40 avatar size with URL-aware fallback avatar
            AvatarView(imageURLOrName: profile.avatar_url, size: 40)

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

// MARK: - FriendRequestRow Avatar helper (matches UserRowView logic)
extension FriendRequestRow {
    @ViewBuilder
    fileprivate func avatarView() -> some View {
        let size: CGFloat = 40
        let glyphSize: CGFloat = size * 0.62
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

        if let avatar = profile.avatar_url,
           avatar.lowercased().hasPrefix("http"),
           let url = URL(string: avatar) {
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

// MARK: - Notifications
// Notification name moved to shared Notifications.swift

#Preview {
    SearchView()
}
