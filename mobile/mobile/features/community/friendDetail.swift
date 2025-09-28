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
    @StateObject private var friendTaskViewModel: TaskListViewModel
    
    init(friend: Friend) {
        self.friend = friend
        self._isFavorite = State(initialValue: friend.isFavorite)
        self._friendTaskViewModel = StateObject(wrappedValue: TaskListViewModel(userId: friend.userId))
    }
    
    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width * 0.9
            let scale = max(0.4, 1 - 0.6 * sheetProgress)
            let shakerSide = fullWidth * scale
            AppColors.neutral1000.ignoresSafeArea()
            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    headerSection
                    // Friend shaker - ShakerView with notes integration
                    ShakerView(
                        viewModel: friendTaskViewModel,
                        onNoteEmojiTapped: { showNotesPopup() }
                    )
                        .frame(width: shakerSide, height: shakerSide)
                        .frame(maxWidth: 275)
                        .padding(.top, 16)
                        .overlay(
                            Group {
                                if !hasLeftTextNote && friendTaskViewModel.hasAnyTasks && scale >= 0.8 {
                                    VStack {
                                        Spacer().frame(height: shakerSide * 0.3)
                                        leaveNoteButton
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
                .appFont(AppFont.title2)
                .frame(maxWidth: .infinity, alignment: .center)

            // Leading/trailing controls
            HStack {
                // Back
                Button(action: { dismiss() }) {
                    Image("left_arrow")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 24, height: 24)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(AppColors.neutral900)
                        )
                }
                Spacer()
                HStack(spacing: 12) {
                    // Calendar
                    Button(action: { showingFriendCalendar = true }) {
                        Image("calendar")
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: 24, height: 24)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle().fill(AppColors.neutral900)
                            )
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
                        Group {
                            if isFavorite {
                                Image("star_on")
                                    .resizable()
                                    .renderingMode(.original)
                            } else {
                                Image("star")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(AppColors.neutral400)
                            }
                        }
                        .frame(width: 24, height: 24)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(AppColors.neutral900)
                        )
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
                .foregroundColor(AppColors.neutral1000)
                .appFont(AppFont.labelL)
                .lineLimit(1)
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
        }
        .frame(width: 180, height: 51)
        .background(AppColors.textWhite.opacity(0.7))
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(AppColors.textWhite, lineWidth: 1)
        )
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


