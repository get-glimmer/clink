import SwiftUI
import SpriteKit

struct FriendDetailView: View {
    let friend: Friend
    @Environment(\.dismiss) private var dismiss
    @State private var sheetProgress: CGFloat = 0
    @State private var showingNoteSheet = false
    @State private var showingNotesPopup = false
    @State private var showingFriendCalendar = false
    @State private var isFavorite: Bool
    @StateObject private var communityViewModel = CommunityViewModel()
    @State private var hasLeftTextNote: Bool = false
    
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
                    headerSection
                    // Friend shaker - ShakerView with notes integration
                    ShakerView(
                        viewModel: TaskListViewModel(userId: friend.userId),
                        onNoteEmojiTapped: { showNotesPopup() }
                    )
                        .frame(width: shakerSide, height: shakerSide)
                        .frame(maxWidth: 275)
                        .padding(.top, 16)
                        .overlay(
                            Group {
                                if !hasLeftTextNote {
                                    VStack {
                                        Spacer().frame(height: shakerSide * 0.3)
                                        leaveNoteButton
                                            .scaleEffect(scale * 0.8)
                                        Spacer()
                                    }
                                }
                            }, alignment: .top
                        )
                }
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
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerNoteAdded)) { notification in
            if let friendUserId = notification.userInfo?["friendUserId"] as? String,
               friendUserId == friend.userId {
                hasLeftTextNote = true
            }
        }
        .task {
            await checkIfUserLeftTextNote()
        }
    }
    
    private var headerSection: some View {
        ZStack {
            // Centered title
            Text(friend.name)
                .foregroundColor(AppColors.textWhite)
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)

            // Leading/trailing controls
            HStack {
                // Back
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(AppColors.textWhite)
                }
                Spacer()
                HStack(spacing: 12) {
                    // Calendar
                    Button(action: { showingFriendCalendar = true }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.textWhite)
                    }
                    // Favorite
                    Button(action: {
                        isFavorite.toggle()
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
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .sheet(isPresented: $showingFriendCalendar) {
            FriendTrackerView(friendUserId: friend.userId, friendName: friend.name)
                .presentationDetents([.large])
        }
    }
    
    private var leaveNoteButton: some View {
        Button(action: { showingNoteSheet = true }) {
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
    
    private func showNotesPopup() { showingNotesPopup = true }
    
    private func checkIfUserLeftTextNote() async {
        guard let currentUserId = getUserId(),
              let userId = UUID(uuidString: currentUserId) else { return }
        do {
            if let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId) {
                let has = try await CommunityService().userHasTextNote(shakerId: shakerId, userId: userId)
                await MainActor.run { self.hasLeftTextNote = has }
            }
        } catch { }
    }
}


