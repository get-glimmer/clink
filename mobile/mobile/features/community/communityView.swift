//
//  communityView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI
import SpriteKit
import UIKit

struct CommunityView: View {

    // CommunityView has `init`, let's check it.
    @Binding var isMenuPresented: Bool
    init(isMenuPresented: Binding<Bool> = .constant(false)) {
        _isMenuPresented = isMenuPresented
    }
    @StateObject private var viewModel = CommunityViewModel()
    @StateObject private var friendRequestRT = FriendRequestRealtimeService()
    @State private var showingSearch = false
    @State private var selectedFriend: Friend? = nil
    @State private var activeMenuFriend: Friend? = nil
    
    
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
                                .appText(AppFont.body1)
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
                                .appText(AppFont.title2)
                            
                            Text(errorMessage)
                                .foregroundColor(AppColors.neutral400)
                                .appText(AppFont.body2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button("Try Again") {
                                viewModel.refreshFriends()
                            }
                            .foregroundColor(AppColors.textWhite)
                            .appText(AppFont.labelL)
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
                                .appText(AppFont.title2)
                            
                            Text("Add friends through the search to see them here")
                                .foregroundColor(AppColors.neutral400)
                                .appText(AppFont.body2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .padding(.top, 40)
                    } else {
                        // Friends grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 13) {
                            ForEach(viewModel.friends) { friend in
                                FriendCardView(
                                    friend: friend, 
                                    isSelected: friend.id == viewModel.selectedFriendId,
                                    viewModel: viewModel,
                                    onTap: {
                                        selectedFriend = friend
                                    },
                                    onMenu: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            activeMenuFriend = friend
                                            isMenuPresented = true
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
                // Pull-to-refresh (native). Requires an extra pull beyond top.
                .refreshable {
                    await MainActor.run { viewModel.refreshFriends() }
                }
            }
        }
        .coordinateSpace(name: "rootOverlay")
        // Dropdown positioned via header anchor (left-aligned, 16pt below header)
        .overlayPreferenceValue(DropdownBoundsPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if viewModel.showingDropdown, let a = anchor {
                    let rect = proxy[a]
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.0001)
                            .ignoresSafeArea()
                            .onTapGesture { viewModel.showingDropdown = false }

                        DropdownSelector(
                            options: viewModel.categories,
                            selectedOption: $viewModel.selectedCategory,
                            onSelect: { category in
                                viewModel.selectCategory(category)
                                viewModel.showingDropdown = false
                            },
                            labelForOption: { labelFor($0) },
                            isPresented: $viewModel.showingDropdown
                        )
                        // Adjust offset to match previous design
                        .offset(x: rect.minX, y: rect.maxY)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.showingDropdown)
                    }
                }
            }
        }
        // Global blur + bottom sheet overlay for friend menu (above everything including nav)
        .overlay {
            if let menuFriend = activeMenuFriend {
                GeometryReader { proxy in
                    let sheetWidth = UIScreen.main.bounds.width + 2
                    let horizontalOverflow = max(0, sheetWidth - proxy.size.width)

                    ZStack(alignment: .bottom) {
                        // Dark blur overlay (match Task OptionsSheet look & feel)
                        ZStack {
                            DarkBlurView(style: .systemChromeMaterialDark)
                                .ignoresSafeArea()
                            Color.black.opacity(0.7)
                                .ignoresSafeArea()
                        }
                        .contentShape(Rectangle())
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeMenuFriend = nil
                                isMenuPresented = false
                            }
                        }

                        // Bottom sheet menu
                        FriendMenuSheet(
                            friend: menuFriend,
                            viewModel: viewModel,
                            onClose: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    activeMenuFriend = nil
                                    isMenuPresented = false
                                }
                            },
                            handleContent: nil
                        )
                        .frame(width: sheetWidth, height: 208 + bottomSafeAreaInset())
                        .offset(x: -horizontalOverflow / 2)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .ignoresSafeArea(edges: .bottom)
                    }
                }
                .ignoresSafeArea(.all) // ensure container uses full screen bounds
                .zIndex(1000)
                .animation(.easeInOut(duration: 0.2), value: activeMenuFriend != nil)
            }
        }
        .fullScreenCover(isPresented: $showingSearch) { SearchView() }
        .task {
            await friendRequestRT.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendRequestsChanged)) { _ in
            // Refresh friends list to show a newly-accepted friend
            viewModel.refreshFriends()
            // Also re-fetch count in case the event came from local action
            Task { await friendRequestRT.fetchPendingCount() }
        }
        .onDisappear {
            Task { await friendRequestRT.stop() }
        }
        .fullScreenCover(item: $selectedFriend) { friend in FriendDetailView(friend: friend) }
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
                        .appText(AppFont.title3)
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 7))
                        .rotationEffect(.degrees(viewModel.showingDropdown ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: viewModel.showingDropdown)
                }
                .padding(.vertical, 8) // remove extra horizontal padding so header aligns with grid
                .background(Color.clear)
                // capture position of chip in global space
                .background(GeometryReader { proxy in
                    let frame = proxy.frame(in: .named("rootOverlay"))
                    Color.clear
                        .preference(key: DropdownXPreferenceKey.self, value: frame.minX)
                        .preference(key: DropdownYPreferenceKey.self, value: frame.maxY)
                })
                .anchorPreference(key: DropdownBoundsPreferenceKey.self, value: .bounds) { $0 }
            }
            
            Spacer()
            
            // Search Button with badge
            Button(action: {
                showingSearch = true
            }) {
                ZStack { // center contents
                    Circle()
                        .fill(AppColors.neutral900)
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 20))
                }
                .overlay(alignment: .topTrailing) {
                    if friendRequestRT.pendingRequestCount > 0 {
                        Text("\(min(friendRequestRT.pendingRequestCount, 99))")
                            .appText(AppFont.captionXS_M)
                            .foregroundColor(Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(width: 18, height: 18, alignment: .center)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 3, y: -3)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
        }
        .padding(.horizontal, 23)
        .padding(.top, 12)
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

// DropdownBoundsPreferenceKey is now in shared/components/DropdownSelector.swift
// If it collides, we should remove this local definition.
// Since DropdownSelector.swift is public/internal, we should check if we can just remove this.
// Assuming DropdownSelector.swift is in the module, we don't need to redeclare it if it's the same name.
// However, in CommunityView it was likely private or internal.
// I will comment it out or remove it to use the one in shared. But wait, `DropdownSelector.swift` defined it as `struct DropdownBoundsPreferenceKey`.
// If I remove it here, it will use the one from DropdownSelector.swift (if visible).
// Let's assume it is visible.

// private struct DropdownBoundsPreferenceKey: PreferenceKey { ... } // Removed


// Polling-based refreshPendingRequests removed – badge count now driven by
// FriendRequestRealtimeService via Supabase Realtime Postgres Changes.

// Helper to read bottom safe area inset for padding adjustments
private func bottomSafeAreaInset() -> CGFloat {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else { return 0 }
    return window.safeAreaInsets.bottom
}

struct FriendCardView: View {
    let friend: Friend
    let isSelected: Bool
    let viewModel: CommunityViewModel
    let onTap: () -> Void
    let onMenu: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width
            let cardHeight = geo.size.height
            // Horizontal paddings scale off the design width (177)
            let headerPadX = cardWidth * (12.0 / 177.0)
            let sidePadding = cardWidth * (21.0 / 177.0)
            // Vertical paddings scale off the design height (213)
            let headerPadTop = cardHeight * (12.0 / 213.0)
            let headerPadBottom = cardHeight * (18.0 / 213.0)
            let bottomPadding = cardHeight * (19.0 / 213.0)
            VStack(spacing: 0) {
                // Header with profile and menu
                HStack {
                    HStack(spacing: 8) {
                        // Profile Image with fallback (URL or local asset)
                        AvatarView(imageURLOrName: friend.profileImageName, size: 24)
                        // Name
                        Text(friend.name)
                            .foregroundColor(AppColors.textWhite)
                            .appText(AppFont.labelL)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .mask(
                                LinearGradient(stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white, location: 0.85),
                                    .init(color: .clear, location: 1.0)
                                ], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    Spacer()
                    // Menu Button
                    Button(action: { onMenu() }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(AppColors.textWhite)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .padding(.horizontal, headerPadX)
                .padding(.top, headerPadTop)
                .padding(.bottom, 24)

                // Friend's Shaker (emoji garden) — square, with 21px side padding and 19px bottom
                ShakerView(viewModel: TaskListViewModel(userId: friend.userId), forceFullMode: false)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, sidePadding)
                    .padding(.bottom, bottomPadding)
            }
            .frame(width: cardWidth, height: geo.size.height, alignment: .top)
            .background(AppColors.neutral900)
            .cornerRadius(16)
        }
        .aspectRatio(177.0/213.0, contentMode: .fit)
        // Removed selection border
        .onTapGesture {
            onTap()
        }
    }

    // Removed duplicate avatar helper (use shared AvatarView instead)
}

struct FriendMenuSheet: View {
    let friend: Friend
    let viewModel: CommunityViewModel
    let onClose: () -> Void
    let handleContent: AnyView?
    
    var body: some View {
        let sheetShape = UnevenRoundedRectangle(
            topLeadingRadius: 32,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 32,
            style: .continuous
        )

        ZStack(alignment: .top) {
            DarkBlurView(style: .systemChromeMaterialDark)
                .overlay(Color.black.opacity(0.58))
                .clipShape(sheetShape)
                .overlay(
                    sheetShape
                        .fill(Color(.neutral1000).opacity(0.2))
                )
                .overlay(
                    sheetShape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(.neutral400).opacity(0.7),
                                    Color(.neutral600).opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .clipShape(sheetShape)

            VStack(spacing: 0) {
                Group {
                    if let handleContent = handleContent {
                        handleContent
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(UIColor(hex: "373636")!))
                            .frame(width: 44, height: 3)
                    }
                }
                .padding(.top, 9)

                Text(friend.name)
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.title3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 23)
                    .padding(.bottom, 14)

                Divider()
                    .background(AppColors.neutral800)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 7)

                VStack(spacing: 16) {
                    Button(action: {
                        handleUnfollow()
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.neutral800)
                                    .frame(width: 44, height: 44)

                                Image("unfollow")
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            }

                            Text("Unfollow")
                                .foregroundColor(AppColors.textWhite)
                                .appText(AppFont.labelL)

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        handleFavoriteToggle()
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.neutral800)
                                    .frame(width: 44, height: 44)

                                Image(friend.isFavorite ? "star_on" : "star")
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            }

                            Text(friend.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                                .foregroundColor(AppColors.textWhite)
                                .appText(AppFont.labelL)

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 25)
                .padding(.leading, 35)
                .padding(.trailing, 0)

                Spacer(minLength: max(53, bottomSafeAreaInset()))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .bottom)
    }
    
    private func handleUnfollow() {
        viewModel.unfollowFriend(named: friend.name)
        onClose()
    }
    
    private func handleFavoriteToggle() {
        if friend.isFavorite {
            viewModel.removeFriendFromFavorites(named: friend.name)
        } else {
            viewModel.addFriendToFavorites(named: friend.name)
        }
        onClose()
    }
}

// Read-only view of friend's tasks
struct FriendTasksView: View {
    let friend: Friend
    /// Date whose tasks should be shown (driven by friend's tracker/calendar)
    let date: Date
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
                        .appFont(AppFont.title3)
                        .foregroundColor(AppColors.textWhite)
                }
                                            .padding(.horizontal, 24)
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
                    VStack(alignment: .leading, spacing: 0) {
                        // Daily section
                        VStack(spacing: 0) {
                            ForEach(categoriesWithTasks.filter { $0.category.type == .daily }) { categoryWithTasks in
                                friendCategoryCard(for: categoryWithTasks)
                            }
                        }
                        // Match TaskListView: `.padding(.horizontal)` defaults to 16
                        .padding(.horizontal)

                        // Archived header
                        HStack {
                            Text("Archived Task")
                                .appFont(AppFont.title3)
                                .foregroundColor(AppColors.textWhite)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 4)

                        // Archived section
                        VStack(spacing: 0) {
                            ForEach(categoriesWithTasks.filter { $0.category.type == .archived }) { categoryWithTasks in
                                friendCategoryCard(for: categoryWithTasks)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .onAppear {
            loadFriendTasks(for: date)
        }
        .refreshable {
            loadFriendTasks(for: date)
        }
        // When the driving date changes (e.g., user taps another day on FriendTrackerView),
        // re-load that day's visible tasks.
        .onChange(of: date) { newDate in
            loadFriendTasks(for: newDate)
        }
    }
    
    // MARK: - Layout helpers (mirror TaskListView)
    private func friendCategoryCard(for categoryWithTasks: CategoryWithTasks) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .foregroundColor(AppColors.neutral900)

            VStack(alignment: .leading, spacing: 25) {
                friendCategoryHeader(for: categoryWithTasks)
                friendTasksSection(for: categoryWithTasks)
            }
            // Match TaskListView.categoryCard internal padding for consistent spacing.
            .padding(.top, 22)
            .padding(.horizontal, 19)
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity, minHeight: categoryWithTasks.tasks.isEmpty ? 60 : 120)
        // Match vertical gap between cards in TaskListView.
        .padding(.vertical, 8)
    }

    private func friendCategoryHeader(for categoryWithTasks: CategoryWithTasks) -> some View {
        HStack {
            Text(categoryWithTasks.category.emoji)
                .font(.system(size: 27))

            HStack(spacing: 0) {
                Text(categoryWithTasks.category.name)
                    .appFont(AppFont.title3)
                    .foregroundColor(AppColors.textWhite)

                if (categoryWithTasks.category.privacyStatus ?? "public") == "user_only" {
                    Image("privacyOnSmall")
                        .accessibilityLabel("Private category")
                }
            }

            Spacer()

            HeartButton(
                categoryId: categoryWithTasks.category.id,
                categoryEmoji: categoryWithTasks.category.emoji,
                friendUserId: friend.userId
            )
        }
    }

    private func friendTasksSection(for categoryWithTasks: CategoryWithTasks) -> some View {
        VStack(alignment: .leading, spacing: 25) {
            ForEach(categoryWithTasks.tasks) { task in
                HStack(spacing: 0) {
                    Image(task.isCompleted ? "checkboxFilled" : "checkboxEmpty")
                        .foregroundColor(AppColors.textWhite)

                    Text(task.title)
                        .appFont(AppFont.body1)
                        .foregroundColor(AppColors.textWhite)
                        .strikethrough(task.isCompleted)
                        // Match TaskListView task content leading padding
                        .padding(.leading, 13.42)

                    Spacer()
                }
            }
        }
    }
    private func loadFriendTasks(for targetDate: Date) {
        Task {
            do {
                isLoading = true
                errorMessage = nil

                let tasks = try await communityService.getFriendTasks(
                    friendId: friend.userId,
                    date: targetDate
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
        // Resolve today's shaker once for the friend
        let shakerId = try? await communityService.getCurrentShakerForUser(userId: friend.userId)
        guard let shakerId else { return }
        for categoryWithTasks in categoriesWithTasks {
            let categoryId = categoryWithTasks.category.id
            do {
                let liked = try await communityService.isLiked(categoryId: categoryId, userId: userId, shakerId: shakerId)
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
    
    // Removed unused friendTaskCategoryView (replaced by TaskCategoryCard elsewhere)
}

// Sheet for leaving a note to friend
struct LeaveNoteSheet: View {
    let friend: Friend
    var onClose: () -> Void = {}
    @State private var noteText = ""
    @State private var isSending = false
    @State private var customEmoji: String = ""
    @State private var isEmojiFieldFocused: Bool = false
    @State private var selectedEmoji: String? = nil
    // Preset emoji reactions, last slot can be replaced by custom emoji selection
    @State private var presetEmojis: [String] = ["👍", "💖", "👏", "🔥", "🎉"]
    
    var body: some View {
        ZStack {
            // Transparent background overlay
            Color.clear
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
            
            // Centered floating modal
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with close button
                    HStack {
                        Spacer()
                        Button(action: {
                            onClose()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppColors.neutral1000)
                        }
                    }
                    .padding(.top, 6)
                    
                    // Title
                    Text("Leave a Note for \(friend.name)!")
                        .appFont(AppFont.title3Semibold)
                        .foregroundColor(AppColors.neutral1000)
                        .padding(.bottom, 20)
                    
                    VStack(spacing: 20) {
                        // Text input area
                        ZStack(alignment: .topLeading) {
                            // White background with 1pt border #E1E5E2 and fixed size
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(red: 225.0/255.0, green: 229.0/255.0, blue: 226.0/255.0), lineWidth: 1)
                                )
                                .frame(height: 130)

                            InsetTextView(
                                text: $noteText,
                                font: .systemFont(ofSize: 16),
                                insets: UIEdgeInsets(top: 19, left: 17, bottom: 19, right: 17)
                            )
                            .frame(height: 130)

                            if noteText.isEmpty {
                                Text("Write a kind word, a cheer, or a sticker 💛")
                                    .foregroundColor(AppColors.neutral600)
                                    .appFont(AppFont.body2)
                                    .padding(.horizontal, 17)
                                    .padding(.top, 19)
                                    .allowsHitTesting(false)
                            }
                        }
                        
                        // Emoji Reactions Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Emoji Reactions")
                                    .appFont(AppFont.buttonL)
                                    .foregroundColor(AppColors.neutral1000)
                Spacer()
                            }
                            
                            // Emoji buttons
                            HStack(spacing: 16) {
                                ForEach(presetEmojis.indices, id: \.self) { idx in
                                    let emoji = presetEmojis[idx]
                                    Button(action: {
                                        // Select emoji; do not submit immediately
                                        if selectedEmoji == emoji {
                                            selectedEmoji = nil
                                        } else {
                                            selectedEmoji = emoji
                                        }
                                    }) {
                                        let isSelected = (selectedEmoji == emoji)
                                        let glow = Color(red: 1.0, green: 0.92, blue: 0.35)
                                        Text(emoji)
                                            .font(.system(size: 40))
                                            .frame(width: 44, height: 44) // fixed layout box to prevent shifting
                                            // Draw glow BELOW the emoji so the glyph stays crisp
                                            .background(
                                                Group {
                                                    if isSelected {
                                                        ZStack {
                                                            Circle()
                                                                .fill(glow.opacity(0.40))
                                                                .frame(width: 50, height: 50)
                                                                .blur(radius: 8)
                                                            Circle()
                                                                .fill(glow.opacity(0.22))
                                                                .frame(width: 58, height: 58)
                                                                .blur(radius: 12)
                                                        }
                                                    }
                                                }
                                            )
                                            .allowsHitTesting(false)
                                    }
                                    .disabled(isSending)
                                }

                                // Plus button to choose custom emoji via keyboard picker
                                Button(action: {
                                    customEmoji = ""
                                    isEmojiFieldFocused = true
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.green300)
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "plus")
                                            .foregroundColor(.white)
                                            .font(.system(size: 18, weight: .light))
                                    }
                                }
                                .disabled(isSending)
                            }
                            // Ensure no implicit animations cause perceived reloads
                            .animation(.none, value: presetEmojis)
                            .animation(.none, value: selectedEmoji)

                            // Hidden UIKit text field to reliably summon keyboard/emoji picker
                            HiddenEmojiTextField(text: $customEmoji, isFirstResponder: $isEmojiFieldFocused)
                                .frame(width: 1, height: 1)
                                .opacity(0.02)
                                .allowsHitTesting(false)
                                .onChange(of: customEmoji) { newValue in
                                    guard !isSending else { return }
                                    if let emoji = newValue.firstEmoji, !emoji.isEmpty {
                                        // Suppress UIKit and SwiftUI animations during keyboard dismiss + emoji swap
                                        let wasEnabled = UIView.areAnimationsEnabled
                                        UIView.setAnimationsEnabled(false)
                                        var tx = Transaction()
                                        tx.disablesAnimations = true
                                        withTransaction(tx) {
                                            isEmojiFieldFocused = false
                                            customEmoji = ""
                                            if !presetEmojis.isEmpty {
                                                presetEmojis[presetEmojis.count - 1] = emoji
                                            } else {
                                                presetEmojis = [emoji]
                                            }
                                            selectedEmoji = emoji
                                        }
                                        DispatchQueue.main.async {
                                            UIView.setAnimationsEnabled(wasEnabled)
                                        }
                                    }
                                }
                        }
                        
                        // Send button (text and/or emoji)
                Button(action: {
                    sendNote()
                }) {
                    HStack {
                        if isSending {
                            ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                                .scaleEffect(0.8)
                        }
                                Text(isSending ? "Sending..." : "Leave Note")
                                    .appFont(AppFont.title3)
                                    .foregroundColor(AppColors.textWhite)
                            }
                            .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
                            .background(AppColors.neutral900)
                            .cornerRadius(8)
                }
                .disabled((noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedEmoji == nil) || isSending)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
                // Card color #F1F3EF
                .background(Color(red: 241.0/255.0, green: 243.0/255.0, blue: 239.0/255.0))
                .cornerRadius(16)
                .onTapGesture { dismissKeyboard() }
                
                // Green tape overlay - positioned on top of the modal
                VStack {
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(AppColors.green300)
                            .frame(width: 58, height: 23)
                            .rotationEffect(.degrees(-23.65))
                            .offset(x: 0, y: -7)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(width: 370, height: 426)
            .padding(.horizontal, 20)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }
    
    private func sendNote() {
        guard let currentUserId = getUserId(),
              let fromUserId = UUID(uuidString: currentUserId) else { return }
        
        isSending = true
        
        Task {
            do {
                // Get or create friend's shaker ID for the selected day
                let shakerId = try await CommunityService().ensureShakerForUser(userId: friend.userId)
                
                let trimmedContent = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Submit the note to database with both fields as applicable
                try await CommunityService().submitNote(
                    to: shakerId,
                    text: trimmedContent.isEmpty ? nil : trimmedContent,
                    emoji: selectedEmoji,
                    fromUserId: fromUserId
                )
                
                // Determine if this is an emoji-only reaction or text (with/without emoji)
                await MainActor.run {
                    let hasText = !trimmedContent.isEmpty
                    if hasText {
                        // Handle text note (with or without emoji)
                        // 1) Refresh sticky notes
                        NotificationCenter.default.post(
                            name: .friendShakerNoteAdded,
                            object: nil,
                            userInfo: ["friendUserId": friend.userId]
                        )
                        // 2) If an emoji was chosen alongside text, also drop a glowing emoji into the jar
                        if let emoji = selectedEmoji {
                            NotificationCenter.default.post(
                                name: .friendShakerEmojiReactionAdded,
                                object: nil,
                                userInfo: [
                                    "friendUserId": friend.userId,
                                    "emoji": emoji
                                ]
                            )
                        }
                    } else if let emoji = selectedEmoji {
                        // Handle emoji-only reaction - add glowing emoji to jar
                        NotificationCenter.default.post(
                            name: .friendShakerEmojiReactionAdded,
                            object: nil,
                            userInfo: [
                                "friendUserId": friend.userId,
                                "emoji": emoji
                            ]
                        )
                    }
                    
                    self.isSending = false
                    self.selectedEmoji = nil
                    self.noteText = ""
                    onClose()
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

    private func dismissKeyboard() {
        isEmojiFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // Removed immediate sendEmojiReaction; emoji is now selected and sent with the Send button.
}

// UITextView with controllable text container insets (fix caret vs placeholder offset)
private struct InsetTextView: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont
    var insets: UIEdgeInsets

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = insets
        tv.font = font
        tv.isScrollEnabled = true
        tv.textColor = .black
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        if uiView.textContainerInset != insets { uiView.textContainerInset = insets }
        if uiView.font != font { uiView.font = font }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: InsetTextView
        init(_ parent: InsetTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
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
                    Image(isLiked ? "heart_on" : "heart")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 26, height: 27)
                        // .scaleEffect(isLiked ? 1.2 : 1.0)
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
                guard let shakerId = try await communityService.getCurrentShakerForUser(userId: friendUserId) else {
                    await MainActor.run { self.isLiked = false }
                    return
                }
                let liked = try await communityService.isLiked(categoryId: categoryId, userId: userId, shakerId: shakerId)
                await MainActor.run { self.isLiked = liked }
            } catch {
                await MainActor.run { self.isLiked = false }
            }
        }
    }
    
    private func toggleLike() {
        guard let currentUserId = getUserId(),
              let userId = UUID(uuidString: currentUserId) else { return }
        
        isLoading = true
        
        Task {
            do {
                let targetLike = !isLiked
                print("[HeartButton] toggleLike tapped. targetLike=\(targetLike) cat=\(categoryId) friend=\(friendUserId)")
                guard let shakerId = try await communityService.getCurrentShakerForUser(userId: friendUserId) else {
                    await MainActor.run {
                        print("🔴 [HeartButton] no shaker for friend today, aborting like toggle")
                        self.isLoading = false
                    }
                    return
                }
                if targetLike {
                    try await communityService.likeCategory(categoryId: categoryId, userId: userId, shakerId: shakerId)
                } else {
                    try await communityService.unlikeCategory(categoryId: categoryId, userId: userId, shakerId: shakerId)
                }

                // Verify persisted state from DB using shaker-based uniqueness
                let verified = try await communityService.isLiked(categoryId: categoryId, userId: userId, shakerId: shakerId)
                await MainActor.run {
                    print("[HeartButton] post-op verification -> isLiked=\(verified)")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isLiked = verified
                    }
                    self.isLoading = false
                    if verified {
                        NotificationCenter.default.post(
                            name: .friendShakerEmojiReactionAdded,
                            object: nil,
                            userInfo: [
                                "friendUserId": friendUserId,
                                "emoji": categoryEmoji
                            ]
                        )
                    } else {
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
                    print("🔴 [HeartButton] toggleLike failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Emoji Detection Helper
// Duplicate emoji helpers removed; using shared String+Emoji.swift

// MARK: - HiddenEmojiTextField (UIKit bridge)
private struct HiddenEmojiTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool

    // UITextField subclass that prefers the emoji keyboard when possible
    private final class EmojiFirstTextField: UITextField {
        override var textInputContextIdentifier: String? { "" } // enable custom input mode
        override var textInputMode: UITextInputMode? {
            for mode in UITextInputMode.activeInputModes {
                if let lang = mode.primaryLanguage, lang == "emoji" { return mode }
            }
            return super.textInputMode
        }
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = EmojiFirstTextField(frame: .zero)
        tf.delegate = context.coordinator
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        // Important: hidden views cannot become first responder
        tf.isHidden = false
        tf.tintColor = .clear // hide caret
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if isFirstResponder && !uiView.isFirstResponder {
            let ok = uiView.becomeFirstResponder()
            print("[EmojiPicker] becomeFirstResponder -> \(ok)")
            // Nudge input view to adopt preferred emoji mode immediately
            DispatchQueue.main.async { uiView.reloadInputViews() }
        } else if !isFirstResponder && uiView.isFirstResponder {
            uiView.resignFirstResponder()
            print("[EmojiPicker] resignFirstResponder")
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: HiddenEmojiTextField
        init(_ parent: HiddenEmojiTextField) { self.parent = parent }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if string.isEmpty { return true }
            parent.text.append(string)
            return false
        }
    }
}

// MARK: - Notification Names
// Notification names moved to shared Notifications.swift

#Preview {
    CommunityView(isMenuPresented: .constant(false))
}
