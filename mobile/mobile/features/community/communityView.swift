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
    @State private var showingSearch = false
    @State private var selectedFriend: Friend? = nil
    
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
                            .foregroundColor(Color.blue)
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
        .fullScreenCover(isPresented: $showingSearch) {
            SearchView()
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
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                )
            }
            
            Spacer()
            
            // Search Button
            Button(action: {
                showingSearch = true
            }) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textWhite)
                    .font(.system(size: 20, weight: .medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .zIndex(99) // Keep header above scroll content but below dropdown
        .overlay(
            // Dropdown Menu
            VStack {
                if viewModel.showingDropdown {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.categories, id: \.self) { category in
                            Button(action: {
                                viewModel.selectCategory(category)
                            }) {
                                HStack {
                                    Text(category)
                                        .foregroundColor(AppColors.textWhite)
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Spacer()
                                    
                                    if category == viewModel.selectedCategory {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColors.textWhite)
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.clear)
                            }
                            
                            // Divider between items (except for last item)
                            if category != viewModel.categories.last {
                                Divider()
                                    .background(AppColors.neutral700)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .background(AppColors.neutral800)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.neutral600, lineWidth: 1)
                    )
                    .offset(y: 50)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showingDropdown)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.trailing, 60) // Leave space so dropdown doesn't go too wide
            .zIndex(100) // Ensure dropdown appears above other content
        )
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
            FriendShakerView(friend: friend)
                .frame(height: 120)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(AppColors.neutral900)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
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

struct FriendShakerView: View {
    let friend: Friend
    @State private var scene: ShakerScene?
    
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let jarSize = CGSize(width: side, height: side)
            
            ZStack {
                // Background jar image
                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)
                
                // SpriteKit scene with friend's emojis
                if let scene = scene {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .frame(width: jarSize.width, height: jarSize.height)
                        .allowsHitTesting(false) // Disable interaction for friend cards
            }
        }
        .onAppear {
                setupScene(jarSize: jarSize)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerNoteAdded)) { notification in
            if let friendUserId = notification.userInfo?["friendUserId"] as? String,
               friendUserId == friend.userId {
                // Add note emoji to this friend's shaker card
                addNoteEmojiToCard()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerEmojiReactionAdded)) { notification in
            if let friendUserId = notification.userInfo?["friendUserId"] as? String,
               let emoji = notification.userInfo?["emoji"] as? String,
               friendUserId == friend.userId {
                // Add glowing emoji reaction to this friend's shaker card
                addGlowingEmojiToCard(emoji)
            }
        }
    }
    
    private func setupScene(jarSize: CGSize) {
        // Keep scene size smaller to maintain emoji scale
        let sceneSize = CGSize(width: 400, height: 400)
        scene = ShakerScene(size: sceneSize)
        
        // Use default boundaries - custom boundaries were causing floating emojis
        // scene?.configureBoundaries(inset: 60, lidHeight: 80)
        
        // Add friend's emojis to the scene with a small delay to ensure proper positioning
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for emoji in friend.emojis {
                let taskId = UUID() // Generate unique ID for each emoji
                scene?.addEmoji(emoji, for: taskId)
            }
        }
        
        // If this shaker has any notes in DB, show a single note emoji
        Task {
            do {
                if let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId),
                   !(try await CommunityService().getNotesForShaker(shakerId: shakerId, limit: 1)).isEmpty {
                    await MainActor.run {
                        let noteEmoji = "🗒️"
                        if scene?.hasEmoji(noteEmoji) != true {
                            let taskId = UUID()
                            scene?.addEmoji(noteEmoji, for: taskId)
                        }
                    }
                }
                
                // Load recent emoji-only reactions and display them as glowing emojis (deduped)
                if let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId) {
                    let recent = try await CommunityService().getNotesForShaker(shakerId: shakerId, limit: 10)
                    let symbols = Array(Set(recent.compactMap { $0.noteContent.isEmojiOnly ? $0.noteContent.firstEmoji : nil })).prefix(5)
                    await MainActor.run {
                        for symbol in symbols {
                            if scene?.hasEmoji(symbol) != true {
                                let taskId = UUID()
                                scene?.addGlowingEmoji(symbol, for: taskId)
                            }
                        }
                    }
                }
            } catch {
                // silently ignore note-check failures
            }
        }
        
        // Disable motion for friend cards (they should be static displays)
        scene?.setMotionEnabled(false)
    }
    
    private func addNoteEmojiToCard() {
        let noteEmoji = "🗒️"
        // Prevent duplicate note emoji in the card scene
        if scene?.hasEmoji(noteEmoji) == true { return }
        let taskId = UUID()
        scene?.addEmoji(noteEmoji, for: taskId)
    }
    
    private func addGlowingEmojiToCard(_ emoji: String) {
        let taskId = UUID()
        scene?.addGlowingEmoji(emoji, for: taskId)
    }
}

struct FriendDetailView: View {
    let friend: Friend
    @Environment(\.dismiss) private var dismiss
    @State private var sheetProgress: CGFloat = 0
    @State private var showingNoteSheet = false
    @State private var showingNotesPopup = false
    @State private var isFavorite: Bool
    @StateObject private var communityViewModel = CommunityViewModel()
    
    init(friend: Friend) {
        self.friend = friend
        self._isFavorite = State(initialValue: friend.isFavorite)
    }
    
    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width * 0.9
            let scale = max(0.4, 1 - 0.6 * sheetProgress)
            let shakerSide = fullWidth * scale
            
            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    // Header with friend name and navigation
                    headerSection
                    
                    // Friend's Shaker
                    FriendShakerDetailView(friend: friend) {
                        // When notes emoji is tapped, show the notes popup
                        showNotesPopup()
                    }
                        .frame(width: shakerSide, height: shakerSide)
                        .frame(maxWidth: 275)
                        .padding(.top, 16)
                        .overlay(
                            // Leave a Note button overlaid on the jar
                            VStack {
                                Spacer()
                                    .frame(height: shakerSide * 0.3) // Position button lower on jar
                                leaveNoteButton
                                    .scaleEffect(scale * 0.8) // Scale with shaker but smaller
                                Spacer()
                            },
                            alignment: .top
                        )
                }
                
                // Bottom Sheet with friend's tasks (read-only)
                BottomSheet(
                    minHeight: 340,
                    maxHeight: 560,
                    progress: $sheetProgress
                ) {
                    FriendTasksView(friend: friend)
                }
            }
            .animation(.easeInOut, value: scale)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNoteSheet) {
            LeaveNoteSheet(friend: friend)
                .presentationBackground(.clear)
                .presentationDetents([.fraction(1.0)])
        }
        .fullScreenCover(isPresented: $showingNotesPopup) {
            NotesPopupView(friend: friend)
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Back button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppColors.textWhite)
            }
            
            Spacer()
            
            // Friend name
            Text(friend.name)
                .foregroundColor(AppColors.textWhite)
                .font(.system(size: 24, weight: .bold))
            
            Spacer()
            
            // Favorite star
            Button(action: {
                // Toggle local state immediately for instant UI feedback
                isFavorite.toggle()
                
                // Update database in background
                if isFavorite {
                    communityViewModel.addFriendToFavorites(named: friend.name)
                } else {
                    communityViewModel.removeFriendFromFavorites(named: friend.name)
                }
            }) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isFavorite ? Color.yellow : AppColors.textWhite)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var leaveNoteButton: some View {
        Button(action: {
            showingNoteSheet = true
        }) {
                Text("Leave a Note")
                    .foregroundColor(AppColors.neutral800)
                    .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
            }
        .frame(width: 180, height: 51)
            .background(AppColors.textWhite)
        .cornerRadius(30)
        }
    
    private func showNotesPopup() {
        // Show popup immediately and load notes inside it
        showingNotesPopup = true
    }
    
}

// Dedicated shaker view for friend detail (with motion enabled)
struct FriendShakerDetailView: View {
    let friend: Friend
    let onNotesEmojiTapped: () -> Void
    @State private var scene: ShakerScene?
    
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let jarSize = CGSize(width: side, height: side)
            
            ZStack {
                // Background jar image
                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)
                
                // SpriteKit scene with friend's emojis
                if let scene = scene {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .frame(width: jarSize.width, height: jarSize.height)
            }
        }
        .onAppear {
                setupScene(jarSize: jarSize)
            }
        }
        .onDisappear {
            scene?.setMotionEnabled(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerNoteAdded)) { notification in
            if let friendUserId = notification.userInfo?["friendUserId"] as? String,
               friendUserId == friend.userId {
                // Add note emoji to this friend's shaker
                addNoteEmoji()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerEmojiReactionAdded)) { notification in
            if let friendUserId = notification.userInfo?["friendUserId"] as? String,
               let emoji = notification.userInfo?["emoji"] as? String,
               friendUserId == friend.userId {
                // Add glowing emoji reaction to this friend's shaker
                addGlowingEmoji(emoji)
            }
        }
    }
    
    private func setupScene(jarSize: CGSize) {
        // Keep scene size smaller to maintain emoji scale  
        let sceneSize = CGSize(width: 275, height: 275)
        scene = ShakerScene(size: sceneSize)
        
        // Use default boundaries - custom boundaries were causing floating emojis  
        // scene?.configureBoundaries(inset: 25, lidHeight: 50)
        
        // Set up the callback for notes emoji taps
        scene?.onNotesEmojiTapped = onNotesEmojiTapped
        
        // Add friend's emojis to the scene
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for emoji in friend.emojis {
                let taskId = UUID()
                scene?.addEmoji(emoji, for: taskId)
            }
        }
        
        // If this shaker has any notes in DB, show a single note emoji
        Task {
            do {
                if let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId),
                   !(try await CommunityService().getNotesForShaker(shakerId: shakerId, limit: 1)).isEmpty {
                    await MainActor.run {
                        let noteEmoji = "🗒️"
                        if scene?.hasEmoji(noteEmoji) != true {
                            let taskId = UUID()
                            scene?.addEmoji(noteEmoji, for: taskId)
                        }
                    }
                }
                
                // Load recent emoji-only reactions and display them as glowing emojis (deduped)
                if let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId) {
                    let recent = try await CommunityService().getNotesForShaker(shakerId: shakerId, limit: 10)
                    let symbols = Array(Set(recent.compactMap { $0.noteContent.isEmojiOnly ? $0.noteContent.firstEmoji : nil })).prefix(5)
                    await MainActor.run {
                        for symbol in symbols {
                            if scene?.hasEmoji(symbol) != true {
                                let taskId = UUID()
                                scene?.addGlowingEmoji(symbol, for: taskId)
                            }
                        }
                    }
                }
            } catch {
                // silently ignore note-check failures
            }
        }
        
        // Enable motion for interactive experience
        scene?.setMotionEnabled(true)
    }
    
    private func addNoteEmoji() {
        let noteEmoji = "🗒️"
        // Prevent duplicate note emoji in the detail scene
        if scene?.hasEmoji(noteEmoji) == true { return }
        let taskId = UUID()
        scene?.addEmoji(noteEmoji, for: taskId)
    }
    
    private func addGlowingEmoji(_ emoji: String) {
        let taskId = UUID()
        scene?.addGlowingEmoji(emoji, for: taskId)
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
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load tasks: \(error.localizedDescription)"
                    self.isLoading = false
                }
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
                    HeartButton(categoryId: categoryWithTasks.category.id)
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
        .onAppear {
            loadLikeStatus()
        }
        .task(id: categoryId) {
            loadLikeStatus()
        }
        .id("heart-\(categoryId.uuidString)")
    }
    
    private func loadLikeStatus() {
        guard let currentUserId = getUserId(),
              let userId = UUID(uuidString: currentUserId) else { 
            return 
        }
        
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

// MARK: - Notes Popup View
struct NotesPopupView: View {
    let friend: Friend
    @State private var notes: [NoteRecord] = []
    @State private var isLoading: Bool = true
    @StateObject private var communityService = CommunityService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
            dismiss()
        }
            
            // Main popup content
            VStack(spacing: 0) {
                // Header with title and close button
                HStack {
                    Text("Notes for \(friend.name)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.neutral800)
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.neutral600)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                // Notes content
                if isLoading {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading notes...")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.neutral600)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else if notes.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.neutral400)
                        
                        Text("No notes yet")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.neutral600)
                        
                        Text("Be the first to leave a note for \(friend.name)!")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.neutral500)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // Notes list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notes) { note in
                                NoteCardView(note: note)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .frame(width: 350, height: 450)
            .background(Color.white)
            .cornerRadius(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            loadNotes()
        }
    }
    
    private func loadNotes() {
        Task {
            isLoading = true
            print("🎬 NotesPopupView loading notes for \(friend.name)")
            
            do {
                // Get the friend's shaker ID for today
                if let shakerId = try await communityService.getCurrentShakerForUser(
                    userId: friend.userId,
                    date: Date()
                ) {
                    // Load random notes for this shaker
                    let loadedNotes = try await communityService.getNotesForShaker(
                        shakerId: shakerId,
                        limit: 5 // Show up to 5 random notes
                    )
                    await MainActor.run {
                        // Filter out emoji-only reactions (they appear as glowing emojis in jar)
                        notes = loadedNotes.filter { !$0.noteContent.isEmojiOnly }
                        isLoading = false
                        print("🎬 NotesPopupView loaded \(notes.count) text notes (filtered out emoji reactions)")
                        print("🎬 Notes: \(notes.map { $0.noteContent })")
                    }
                } else {
                    await MainActor.run {
                        notes = []
                        isLoading = false
                        print("🎬 NotesPopupView: No shaker found")
                    }
                }
            } catch {
                await MainActor.run {
                    notes = []
                    isLoading = false
                    print("🎬 NotesPopupView error: \(error)")
                }
            }
        }
    }
}

// MARK: - Note Card View
struct NoteCardView: View {
    let note: NoteRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Note content
            Text(note.noteContent)
                .font(.system(size: 15))
                .foregroundColor(AppColors.neutral800)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Timestamp
            HStack {
                Spacer()
                Text(timeAgoString(from: note.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.neutral500)
            }
        }
        .padding(16)
        .background(AppColors.neutral100)
        .cornerRadius(12)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
}

#Preview {
    CommunityView()
}
