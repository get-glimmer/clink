//
//  communityView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI
import SpriteKit

struct CommunityView: View {
    @Binding var isMenuPresented: Bool
    init(isMenuPresented: Binding<Bool> = .constant(false)) {
        _isMenuPresented = isMenuPresented
    }
    @StateObject private var viewModel = CommunityViewModel()
    @StateObject private var searchService = UserSearchService()
    @State private var showingSearch = false
    @State private var selectedFriend: Friend? = nil
    @State private var activeMenuFriend: Friend? = nil
    @State private var pendingRequestCount: Int = 0
    @State private var dropdownAnchorX: CGFloat = 0
    @State private var dropdownAnchorY: CGFloat = 0
    @State private var enableBadgeTick: Bool = false
    private let badgeTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var isBadgePolling: Bool = false
    
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
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 20) {
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
                        .padding(.horizontal, 20)
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
                                            .appText(AppFont.labelL)
                                        Spacer(minLength: 0)
                                        if categoriesEqual(category, viewModel.selectedCategory) {
                                            Image("checkMark")
                                                .renderingMode(.template)
                                                .foregroundColor(AppColors.textWhite)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .frame(height: rowHeight, alignment: .center)
                                }
                                if category != viewModel.categories.last {
                                    Divider()
                                        .frame(height: dividerThickness)
                                        .background(AppColors.neutral800)
                                        .padding(.horizontal, 20)
                                }
                            }
                            Spacer(minLength: verticalPad)
                        }
                        .frame(width: 178, height: 152, alignment: .topLeading)
                        .background(AppColors.neutral900)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.neutral600, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .offset(x: rect.minX, y: rect.maxY)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.showingDropdown)
                    }
                }
            }
        }
        // Global blur + bottom sheet overlay for friend menu (above everything including nav)
        .overlay {
            if let menuFriend = activeMenuFriend {
                ZStack(alignment: .bottom) {
                    // Blur overlay covering everything including nav bar
                    Color.black.opacity(0.15)
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea(.all)
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .ignoresSafeArea(edges: .bottom)
                }
                .ignoresSafeArea(.all) // ensure container uses full screen bounds
                .zIndex(1000)
                .animation(.easeInOut(duration: 0.2), value: activeMenuFriend != nil)
            }
        }
        .fullScreenCover(isPresented: $showingSearch) {
            SearchView()
        }
        .onAppear {
            Task { await refreshPendingRequests() }
            enableBadgeTick = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendRequestsChanged)) { _ in
            Task { await refreshPendingRequests() }
            // Also refresh friends list to show the new accepted friend preview
            viewModel.refreshFriends()
        }
        .onReceive(badgeTimer) { _ in
            guard enableBadgeTick else { return }
            Task { await refreshPendingRequests() }
        }
        .onDisappear { enableBadgeTick = false }
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
                    if pendingRequestCount > 0 {
                        Text("\(min(pendingRequestCount, 99))")
                            .appText(AppFont.captionXS_M)
                            .foregroundColor(Color.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
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

private struct DropdownBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
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
                        avatarView(for: friend)
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
                .padding(.bottom, headerPadBottom)

                // Friend's Shaker (emoji garden) — square, with 21px side padding and 19px bottom
                ShakerView(viewModel: TaskListViewModel(userId: friend.userId))
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(12)
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

    // MARK: - Avatar Helper
    @ViewBuilder
    private func avatarView(for friend: Friend) -> some View {
        let size: CGFloat = 24
        let glyphSize: CGFloat = size * 0.62 // better visual balance inside the circle
        // Helper producing an Instagram-like default avatar: gray circle + profile asset
        let fallbackAvatar = AnyView(
            ZStack {
                Circle()
                    .fill(AppColors.neutral800)
                Image("profile") // asset under Assets.xcassets/Nav/profile.imageset
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(AppColors.textWhite)
                    .frame(width: glyphSize, height: glyphSize)
                Circle()
                    .stroke(AppColors.neutral700, lineWidth: 1)
            }
            .frame(width: size, height: size)
        )

        if let url = URL(string: friend.profileImageName), friend.profileImageName.lowercased().hasPrefix("http") {
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
            // Non-URL value → show default avatar consistently
            fallbackAvatar
                .clipShape(Circle())
        }
    }
}

struct FriendMenuSheet: View {
    let friend: Friend
    let viewModel: CommunityViewModel
    let onClose: () -> Void
    let handleContent: AnyView?
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle (customizable)
            Group {
                if let handleContent = handleContent {
                    handleContent
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.neutral600)
                        .frame(width: 44, height: 3)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        
        // Friend name
        Text(friend.name)
            .foregroundColor(AppColors.textWhite)
            .appText(AppFont.title3)
            .padding(.bottom, 24)
        
        // Divider line
        Rectangle()
            .fill(AppColors.neutral800)
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .padding(.horizontal, 16)
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
                                .frame(width: 44, height: 44)
                            
                            Image("unfollow")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        }
                        
                        Text("Unfollow")
                            .foregroundColor(AppColors.textWhite)
                            .appText(AppFont.labelM)
                        
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
                                .frame(width: 44, height: 44)
                            
                            Image(friend.isFavorite ? "star_on" : "star")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        }
                        
                        Text(friend.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                            .foregroundColor(AppColors.textWhite)
                            .appText(AppFont.labelM)
                        
                        Spacer()
                    }
                                                .padding(.horizontal, 28)
                }
            }
        }
        // Add safe-area aware internal padding so content is not clipped by the home indicator
        .padding(.bottom, max(16, bottomSafeAreaInset()))
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(AppColors.neutral1000.opacity(0.5))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 16,
                style: .circular
            )
        )
        .overlay(alignment: .top) {
            // Exact top edge + corner arcs to the very edges (no padding)
            GeometryReader { geo in
                let w = geo.size.width
                let r: CGFloat = 16
                Path { p in
                    // Start at left vertical tangent
                    p.move(to: CGPoint(x: 0, y: r))
                    // Left corner arc up to the top edge
                    p.addArc(
                        center: CGPoint(x: r, y: r),
                        radius: r,
                        startAngle: .degrees(180),
                        endAngle: .degrees(270),
                        clockwise: false
                    )
                    // Top straight segment
                    p.addLine(to: CGPoint(x: w - r, y: 0))
                    // Right corner arc down to the right vertical tangent
                    p.addArc(
                        center: CGPoint(x: w - r, y: r),
                        radius: r,
                        startAngle: .degrees(270),
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                }
                .stroke(AppColors.neutral400, style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter))
            }
            .frame(height: 16)
        }
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
    CommunityView(isMenuPresented: .constant(false))
}
