//
//  communityView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI
import SpriteKit

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @StateObject private var searchService = UserSearchService()
    @State private var showingSearch = false
    @State private var selectedFriend: Friend? = nil
    @State private var pendingRequestCount: Int = 0
    @State private var dropdownAnchorX: CGFloat = 0
    @State private var dropdownAnchorY: CGFloat = 0
    
    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Friends Grid
                ScrollView {
                    if viewModel.isLoading {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.textWhite))
                                .scaleEffect(1.2)
                            
                            Text("Loading friends...")
                                .foregroundColor(AppColors.textWhite)
                                .font(.system(size: 16))
                        }
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .padding(.top, 40)
                    } else if let errorMessage = viewModel.errorMessage {
                        // Error state
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(AppColors.neutral400)
                                .font(.system(size: 40))
                            
                            Text("Something went wrong")
                                .foregroundColor(AppColors.textWhite)
                                .font(.system(size: 18, weight: .medium))
                            
                            Text(errorMessage)
                                .foregroundColor(AppColors.neutral400)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button("Try Again") {
                                viewModel.refreshFriends()
                            }
                            .foregroundColor(AppColors.textWhite)
                            .font(.system(size: 16, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .padding(.top, 40)
                    } else if viewModel.friends.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "person.2")
                                .foregroundColor(AppColors.neutral400)
                                .font(.system(size: 40))
                            
                            Text("No friends yet")
                                .foregroundColor(AppColors.textWhite)
                                .font(.system(size: 18, weight: .medium))
                            
                            Text("Add friends through the search to see them here")
                                .foregroundColor(AppColors.neutral400)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .padding(.top, 40)
                    } else {
                        // Friends grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 20) {
                            ForEach(viewModel.friends) { friend in
                                FriendCardView(
                                    friend: friend, 
                                    isSelected: friend.id == viewModel.selectedFriendId,
                                    viewModel: viewModel
                                ) {
                                    selectedFriend = friend
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
        }
        .coordinateSpace(name: "rootOverlay")
        // Global overlay for dropdown positioned under the button
        .overlay(alignment: .topLeading) {
            if viewModel.showingDropdown {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.0001)
                        .ignoresSafeArea()
                        .onTapGesture { viewModel.showingDropdown = false }

                    VStack(alignment: .leading, spacing: 0) {
                        let rowHeight: CGFloat = 44
                        let dividerThickness: CGFloat = 1
                        let totalRows = CGFloat(viewModel.categories.count) * rowHeight
                        let totalDividers = CGFloat(max(0, viewModel.categories.count - 1)) * dividerThickness
                        let contentHeight = totalRows + totalDividers
                        let containerHeight: CGFloat = 152
                        let verticalPad = max(0, (containerHeight - contentHeight) / 2)
                        Spacer(minLength: verticalPad)
                        ForEach(viewModel.categories, id: \.self) { category in
                            Button(action: { viewModel.selectCategory(category) }) {
                                HStack(spacing: 0) {
                                    Text(labelFor(category))
                                        .foregroundColor(AppColors.textWhite)
                                        .font(.system(size: 18, weight: .medium))
                                    Spacer(minLength: 0)
                                    if categoriesEqual(category, viewModel.selectedCategory) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColors.textWhite)
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .frame(height: rowHeight, alignment: .center)
                            }
                            if category != viewModel.categories.last {
                                Divider()
                                    .frame(height: dividerThickness)
                                    .background(AppColors.neutral700)
                                    .padding(.horizontal, 20)
                            }
                        }
                        Spacer(minLength: verticalPad)
                    }
                    .frame(width: 178, height: 152, alignment: .topLeading)
                    .background(AppColors.neutral800)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.neutral600, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .offset(x: dropdownAnchorX, y: dropdownAnchorY + 52)
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.showingDropdown)
            }
        }
        .fullScreenCover(isPresented: $showingSearch) {
            SearchView()
        }
        .onAppear {
            Task {
                await refreshPendingRequests()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendRequestsChanged)) { _ in
            Task { await refreshPendingRequests() }
            // Also refresh friends list to show the new accepted friend preview
            viewModel.refreshFriends()
        }
        .fullScreenCover(item: $selectedFriend) { friend in
            FriendDetailView(friend: friend)
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Friends Dropdown Button
            Button(action: {
                viewModel.toggleDropdown()
            }) {
                HStack(spacing: 8) {
                    Text(viewModel.selectedCategory)
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 20, weight: .medium))
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 14, weight: .medium))
                        .rotationEffect(.degrees(viewModel.showingDropdown ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: viewModel.showingDropdown)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.clear)
                // capture position of chip in global space
                .background(GeometryReader { proxy in
                    let frame = proxy.frame(in: .named("rootOverlay"))
                    Color.clear
                        .preference(key: DropdownXPreferenceKey.self, value: frame.minX)
                        .preference(key: DropdownYPreferenceKey.self, value: frame.maxY)
                })
            }
            
            Spacer()
            
            // Search Button with badge
            Button(action: {
                showingSearch = true
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 20, weight: .medium))
                    if pendingRequestCount > 0 {
                        Text("\(min(pendingRequestCount, 99))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        // capture header height
        .onPreferenceChange(DropdownXPreferenceKey.self) { dropdownAnchorX = $0 }
        .onPreferenceChange(DropdownYPreferenceKey.self) { dropdownAnchorY = $0 }
        .zIndex(99) // Keep header above scroll content but below dropdown
    }

    private func labelFor(_ category: String) -> String {
        switch category {
        case "Friends": return "Friend"
        case "Favorites": return "Favorite"
        default: return category
        }
    }
    private func categoriesEqual(_ a: String, _ b: String) -> Bool {
        func norm(_ s: String) -> String {
            if s == "Friends" { return "Friend" }
            if s == "Favorites" { return "Favorite" }
            return s
        }
        return norm(a) == norm(b)
    }
}

// MARK: - Preference Keys for dropdown positioning
private struct DropdownXPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct DropdownYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private extension CommunityView {
    func refreshPendingRequests() async {
        do {
            let incoming = try await searchService.getIncomingFriendRequests()
            await MainActor.run { self.pendingRequestCount = incoming.count }
        } catch {
            await MainActor.run { self.pendingRequestCount = 0 }
        }
    }
}

struct FriendCardView: View {
    let friend: Friend
    let isSelected: Bool
    let viewModel: CommunityViewModel
    let onTap: () -> Void
    @State private var showingMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with profile and menu
            HStack {
                HStack(spacing: 8) {
                    // Profile Image
                    Image(friend.profileImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    
                    // Name
                    Text(friend.name)
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Spacer()
                
                // Menu Button
                Button(action: {
                    showingMenu = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Friend's Shaker (emoji garden)
            ShakerView(viewModel: TaskListViewModel(userId: friend.userId))
                .frame(height: 120)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(AppColors.neutral900)
        .cornerRadius(16)
        // Removed selection border
        .onTapGesture {
            onTap()
        }
        .sheet(isPresented: $showingMenu) {
            FriendMenuSheet(friend: friend, viewModel: viewModel)
        }
    }
}

struct FriendMenuSheet: View {
    let friend: Friend
    let viewModel: CommunityViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(AppColors.neutral600)
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 32)
        
        // Friend name
        Text(friend.name)
            .foregroundColor(AppColors.textWhite)
            .font(.system(size: 28, weight: .bold))
            .padding(.bottom, 24)
        
        // Divider line
        Rectangle()
            .fill(AppColors.neutral800)
            .frame(width: 361, height: 1)
            .padding(.bottom, 24)
        
                    // Menu options
            VStack(spacing: 24) {
                // Unfollow option
                Button(action: {
                    handleUnfollow()
                }) {
                    HStack(spacing: 20) {
                        // Circular icon background
                        ZStack {
                            Circle()
                                .fill(AppColors.neutral800)
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "person.badge.minus")
                                .foregroundColor(AppColors.textWhite)
                                .font(.system(size: 24, weight: .medium))
                        }
                        
                        Text("Unfollow")
                            .foregroundColor(AppColors.textWhite)
                            .font(.system(size: 20, weight: .medium))
                        
                        Spacer()
                    }
                                                .padding(.horizontal, 28)
                }
                
                // Favorites option (add or remove based on current status)
                Button(action: {
                    handleFavoriteToggle()
                }) {
                    HStack(spacing: 20) {
                        // Circular icon background
                        ZStack {
                            Circle()
                                .fill(AppColors.neutral800)
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: friend.isFavorite ? "star.fill" : "star")
                                .foregroundColor(friend.isFavorite ? Color.yellow : AppColors.textWhite)
                                .font(.system(size: 24, weight: .medium))
                        }
                        
                        Text(friend.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                            .foregroundColor(AppColors.textWhite)
                            .font(.system(size: 20, weight: .medium))
                        
                        Spacer()
                    }
                                                .padding(.horizontal, 28)
                }
            }
        
        Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.neutral1000)
        .presentationDetents([.height(254)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(.regularMaterial)
    }
    
    private func handleUnfollow() {
        viewModel.unfollowFriend(named: friend.name)
        dismiss()
    }
    
    private func handleFavoriteToggle() {
        if friend.isFavorite {
            viewModel.removeFriendFromFavorites(named: friend.name)
        } else {
            viewModel.addFriendToFavorites(named: friend.name)
        }
        dismiss()
    }
}

// Read-only view of friend's tasks
struct FriendTasksView: View {
    let friend: Friend
    @StateObject private var communityService = CommunityService()
    @State private var categoriesWithTasks: [CategoryWithTasks] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Daily Task")
                        .font(.headline)
                        .foregroundColor(AppColors.textWhite)
                }
                                            .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 4)
                
                // Content based on loading state
                if isLoading {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.textWhite))
                            .scaleEffect(1.2)
                        
                        Text("Loading tasks...")
                            .foregroundColor(AppColors.textWhite)
                            .font(.system(size: 16))
                    }
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .padding(.top, 40)
                } else if let errorMessage = errorMessage {
                    // Error state
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(AppColors.neutral400)
                            .font(.system(size: 40))
                        
                        Text("Could not load tasks")
                            .foregroundColor(AppColors.textWhite)
                            .font(.system(size: 18, weight: .medium))
                        
                        Text(errorMessage)
                            .foregroundColor(AppColors.neutral400)
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .padding(.top, 40)
                } else if categoriesWithTasks.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(AppColors.neutral400)
                            .font(.system(size: 40))
                        
                        Text("No visible tasks")
                            .foregroundColor(AppColors.textWhite)
                            .font(.system(size: 18, weight: .medium))
                        
                        Text("\(friend.name) hasn't shared any tasks for today")
                            .foregroundColor(AppColors.neutral400)
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .padding(.top, 40)
                } else {
                    // Friend's real tasks
                    VStack(spacing: 16) {
                        ForEach(categoriesWithTasks) { categoryWithTasks in
                            friendTaskCategoryView(categoryWithTasks: categoryWithTasks)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
        }
        .onAppear {
            loadFriendTasks()
        }
        .refreshable {
            loadFriendTasks()
        }
    }
    
    private func loadFriendTasks() {
        Task {
            do {
                isLoading = true
                errorMessage = nil
                
                let tasks = try await communityService.getFriendTasks(
                    friendId: friend.userId,
                    date: Date() // Today's tasks
                )
                
                await MainActor.run {
                    self.categoriesWithTasks = tasks
                    self.isLoading = false
                }
                
                // After loading tasks, pre-populate shaker with any categories the current user already liked
                await addLikedCategoryEmojisToShaker()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load tasks: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Checks which of friend's categories are already liked by the current user and posts events to show glowing emojis.
    private func addLikedCategoryEmojisToShaker() async {
        guard let currentUserId = getUserId(),
              let userId = UUID(uuidString: currentUserId) else { return }
        
        var addedSymbols: Set<String> = []
        for categoryWithTasks in categoriesWithTasks {
            let categoryId = categoryWithTasks.category.id
            do {
                let liked = try await communityService.isLiked(categoryId: categoryId, userId: userId)
                if liked {
                    let symbol = categoryWithTasks.category.emoji
                    if !addedSymbols.contains(symbol) {
                        addedSymbols.insert(symbol)
                        NotificationCenter.default.post(
                            name: .friendShakerEmojiReactionAdded,
                            object: nil,
                            userInfo: [
                                "friendUserId": friend.userId,
                                "emoji": symbol
                            ]
                        )
                    }
                }
            } catch {
                // ignore like check errors here
            }
        }
    }
    
    private func friendTaskCategoryView(categoryWithTasks: CategoryWithTasks) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .foregroundColor(AppColors.neutral900)
            
            VStack(alignment: .leading, spacing: 20) {
                // Category header
                HStack {
                    Text(categoryWithTasks.category.emoji)
                        .font(.system(size: 24))
                    Text(categoryWithTasks.category.name)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textWhite)
                    Spacer()
                    
                    // Like button for all categories
                    HeartButton(
                        categoryId: categoryWithTasks.category.id,
                        categoryEmoji: categoryWithTasks.category.emoji,
                        friendUserId: friend.userId
                    )
                }
                
                // Tasks (read-only)
                ForEach(categoryWithTasks.tasks) { task in
                    HStack(spacing: 12) {
                        // Checkbox (read-only)
                        Image(task.isCompleted ? "checkboxFilled" : "checkboxEmpty")
                            .foregroundColor(AppColors.textWhite)
                        
                        // Task text
                        Text(task.title)
                            .font(.system(size: 16))
                            .strikethrough(task.isCompleted)
                            .foregroundColor(AppColors.textWhite)
                        
                        Spacer()
                    }
                }
            }
            .padding(20)
        }
        .padding(.vertical, 8)
    }
}

// Sheet for leaving a note to friend
struct LeaveNoteSheet: View {
    let friend: Friend
    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""
    @State private var isSending = false
    
    private let emojiReactions = ["👍", "💗", "👏", "🔥", "🙏", "🌈"]
    
    var body: some View {
        ZStack {
            // Transparent background overlay
            Color.clear
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Centered floating modal
            ZStack {
                VStack(spacing: 0) {
                    // Header with close button
                    HStack {
                        Spacer()
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color.black)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                    
                    // Title
                    Text("Leave a Note for \(friend.name)!")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.black)
                        .padding(.bottom, 20)
                    
                    VStack(spacing: 20) {
                        // Text input area
                ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                        .frame(height: 120)
                    
                    TextEditor(text: $noteText)
                                .foregroundColor(Color.black)
                        .font(.system(size: 16))
                                .padding(16)
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    
                    if noteText.isEmpty {
                                Text("Write a kind word, a cheer, or a sticker 💛")
                                    .foregroundColor(Color.gray.opacity(0.6))
                            .font(.system(size: 16))
                                    .padding(.horizontal, 20)
                                    .padding(.top, 24)
                            .allowsHitTesting(false)
                    }
                }
                        .padding(.horizontal, 28)
                        
                        // Emoji Reactions Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Emoji Reactions")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color.black)
                Spacer()
                            }
                            .padding(.horizontal, 28)
                            
                            // Emoji buttons
                            HStack(spacing: 16) {
                                ForEach(emojiReactions, id: \.self) { emoji in
                                    Button(action: {
                                        // Submit emoji reaction immediately
                                        sendEmojiReaction(emoji)
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                Circle()
                                                    .fill(Color.gray.opacity(0.1))
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                                    )
                                            )
                                            .scaleEffect(isSending ? 0.9 : 1.0)
                                            .animation(.easeInOut(duration: 0.1), value: isSending)
                                    }
                                    .disabled(isSending)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                        
                        // Divider
                        HStack {
                            VStack { Divider() }
                            Text("OR")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.gray)
                                .padding(.horizontal, 8)
                            VStack { Divider() }
                        }
                        .padding(.horizontal, 28)
                        
                        // Send Text Note button
                Button(action: {
                    sendNote()
                }) {
                    HStack {
                        if isSending {
                            ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                                .scaleEffect(0.8)
                        }
                                Text(isSending ? "Sending..." : "Send Text Note")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color.white)
                            }
                            .frame(height: 48)
                    .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .cornerRadius(24)
                }
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                    }
                }
                .background(Color.white)
                .cornerRadius(16)
                
                // Green tape overlay - positioned on top of the modal
                VStack {
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(AppColors.green500)
                            .frame(width: 80, height: 30)
                            .cornerRadius(4)
                            .rotationEffect(.degrees(15))
                            .offset(x: -20, y: -10)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(width: 370, height: 426)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }
    
    private func sendNote() {
        guard !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let currentUserId = getUserId(),
              let fromUserId = UUID(uuidString: currentUserId) else { return }
        
        isSending = true
        
        Task {
            do {
                // Get friend's current shaker ID
                guard let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId) else {
                    throw NSError(domain: "NoteError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find friend's shaker"])
                }
                
                let trimmedContent = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Submit the note to database
                try await CommunityService().submitNote(
                    to: shakerId,
                    content: trimmedContent,
                    fromUserId: fromUserId
                )
                
                // Determine if this is an emoji reaction or text note
                await MainActor.run {
                    if trimmedContent.isEmojiOnly {
                        // Handle emoji reaction - add glowing emoji to jar
                        if let emoji = trimmedContent.firstEmoji {
                            NotificationCenter.default.post(
                                name: .friendShakerEmojiReactionAdded,
                                object: nil,
                                userInfo: [
                                    "friendUserId": friend.userId,
                                    "emoji": emoji
                                ]
                            )
                        }
                    } else {
                        // Handle text note - add note emoji to jar
                        NotificationCenter.default.post(
                            name: .friendShakerNoteAdded,
                            object: nil,
                            userInfo: ["friendUserId": friend.userId]
                        )
                    }
                    
                    self.isSending = false
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isSending = false
                    // Show error to user
                    print("Error sending note: \(error)")
                }
            }
        }
    }
    
    private func sendEmojiReaction(_ emoji: String) {
        guard let currentUserId = getUserId(),
              let fromUserId = UUID(uuidString: currentUserId) else { return }
        
        isSending = true
        
        Task {
            do {
                // Get friend's current shaker ID
                guard let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId) else {
                    throw NSError(domain: "EmojiReactionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find friend's shaker"])
                }
                
                // Submit the emoji reaction to database
                try await CommunityService().submitNote(
                    to: shakerId,
                    content: emoji,
                    fromUserId: fromUserId
                )
                
                // Notify any open friend shaker views to add the glowing emoji
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .friendShakerEmojiReactionAdded,
                        object: nil,
                        userInfo: [
                            "friendUserId": friend.userId,
                            "emoji": emoji
                        ]
                    )
                    
                    self.isSending = false
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isSending = false
                    // Show error to user
                    print("Error sending emoji reaction: \(error)")
                }
            }
        }
    }
}

// Interactive heart button component
struct HeartButton: View {
    let categoryId: UUID
    let categoryEmoji: String
    let friendUserId: String
    @State private var isLiked: Bool = false
    @State private var isLoading: Bool = false
    @StateObject private var communityService = CommunityService()
    
    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            toggleLike()
        }) {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.neutral400))
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor(isLiked ? .red : AppColors.neutral400)
                        .scaleEffect(isLiked ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isLiked)
                }
            }
        }
        .disabled(isLoading)
        .onAppear { loadLikeStatus() }
        .task(id: categoryId) { loadLikeStatus() }
        .id("heart-\(categoryId.uuidString)")
    }
    
    private func loadLikeStatus() {
        guard let currentUserId = getUserId(),
              let userId = UUID(uuidString: currentUserId) else { return }
        Task {
            do {
                let liked = try await communityService.isLiked(categoryId: categoryId, userId: userId)
                await MainActor.run {
                    self.isLiked = liked
                }
            } catch {
                // Silently handle errors
            }
        }
    }
    
    private func toggleLike() {
        guard let currentUserId = getUserId(),
              let userId = UUID(uuidString: currentUserId) else { return }
        
        isLoading = true
        
        Task {
            do {
                let willLike = !isLiked
                if isLiked {
                    try await communityService.unlikeCategory(categoryId: categoryId, userId: userId)
                } else {
                    try await communityService.likeCategory(categoryId: categoryId, userId: userId)
                }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isLiked.toggle()
                    }
                    self.isLoading = false
                    // On like, drop the category emoji as a glowing reaction in the jar
                    if willLike {
                        NotificationCenter.default.post(
                            name: .friendShakerEmojiReactionAdded,
                            object: nil,
                            userInfo: [
                                "friendUserId": friendUserId,
                                "emoji": categoryEmoji
                            ]
                        )
                    } else {
                        // On unlike, remove one occurrence of the emoji from the jar
                        NotificationCenter.default.post(
                            name: .friendShakerEmojiReactionRemoved,
                            object: nil,
                            userInfo: [
                                "friendUserId": friendUserId,
                                "emoji": categoryEmoji
                            ]
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Error toggling like: \(error)")
                }
            }
        }
    }
}

// MARK: - Emoji Detection Helper
extension String {
    var isEmojiOnly: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // Check if string contains only emoji characters
        for scalar in trimmed.unicodeScalars {
            if !scalar.properties.isEmoji {
                return false
            }
        }
        return true
    }
    
    var firstEmoji: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        for scalar in trimmed.unicodeScalars {
            if scalar.properties.isEmoji {
                return String(scalar)
            }
        }
        return nil
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let friendShakerNoteAdded = Notification.Name("friendShakerNoteAdded")
    static let friendShakerEmojiReactionAdded = Notification.Name("friendShakerEmojiReactionAdded")
    static let friendShakerEmojiReactionRemoved = Notification.Name("friendShakerEmojiReactionRemoved")
}

#Preview {
    CommunityView()
}
