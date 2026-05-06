import SwiftUI
import SpriteKit

struct FriendDetailView: View {
    let friend: Friend
    @Environment(\.dismiss) private var dismiss
    @State private var sheetProgress: CGFloat = 0
    @State private var showingNoteSheet = false
    @State private var showingNotesPopup = false
    @State private var showingCalendar = false
    @State private var isFavorite: Bool
    @StateObject private var communityViewModel = CommunityViewModel()
    @State private var hasLeftTextNote: Bool = false
    @State private var hasAnyNotes: Bool = false
    @StateObject private var friendTaskViewModel: TaskListViewModel
    @State private var emojiObserver: NSObjectProtocol?
    
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
            // Match TaskView's BottomSheet sizing so the jar→header gap feels the same.
            let screenHeight = geo.size.height
            let minSheetHeight = screenHeight / 794 * 340
            let maxSheetHeight = screenHeight / 794 * 560
            AppColors.neutral1000.ignoresSafeArea()
            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    headerSection
                    // Toggle between Shaker and Calendar
                    Group {
                        if showingCalendar {
                            FriendTrackerView(
                                friendUserId: friend.userId,
                                friendName: friend.name,
                                friendTaskViewModel: friendTaskViewModel
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            ShakerView(
                                viewModel: friendTaskViewModel,
                                forceFullMode: true,
                                showStickyNotes: (sheetProgress == 0),
                                onNoteTapped: { note in
                                    showNotesPopup(note)
                                }
                            )
                                .frame(width: shakerSide, height: shakerSide)
                                .frame(maxWidth: 275)
                                .overlay(
                                    Group {
                                        // Allow leaving a note even if the friend has no tasks in the shaker.
                                        // Previously this was gated by `friendTaskViewModel.hasAnyTasks`.
                                        if !hasLeftTextNote && scale >= 0.8 {
                                            VStack {
                                                Spacer().frame(height: shakerSide * 0.3)
                                                leaveNoteButton
                                                Spacer()
                                            }
                                        }
                                    }, alignment: .top
                                )
                        }
                    }
                    .padding(.top, showingCalendar ? 2 : 16)
                }
                BottomSheet(
                    minHeight: minSheetHeight,
                    maxHeight: maxSheetHeight,
                    progress: $sheetProgress
                ) {
                    FriendTasksView(
                        friend: friend,
                        date: friendTaskViewModel.taskSelectedDate
                    )
                }
            }
            .animation(.easeInOut, value: scale)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        // Buffer emoji drops while calendar is visible; replay when returning to shaker
        .onAppear {
            // Avoid multiple observers
            if emojiObserver == nil {
                emojiObserver = NotificationCenter.default.addObserver(forName: .friendShakerEmojiReactionAdded, object: nil, queue: .main) { note in
                guard showingCalendar,
                      let fid = note.userInfo?["friendUserId"] as? String,
                      fid == friend.userId,
                      let emoji = note.userInfo?["emoji"] as? String else { return }
                PendingEmojiDropStore.shared.enqueue(friendId: fid, emoji: emoji)
                }
                // Buffer text-note add while on calendar
                NotificationCenter.default.addObserver(forName: .friendShakerNoteAdded, object: nil, queue: .main) { note in
                    guard showingCalendar,
                          let fid = note.userInfo?["friendUserId"] as? String,
                          fid == friend.userId else { return }
                    PendingNoteStore.shared.markPending(for: fid)
                }
            }
        }
        .onChange(of: showingCalendar) { _, isCalendar in
            // When switching back to shaker, replay buffered emojis and re-check note status
            if !isCalendar {
                let pending = PendingEmojiDropStore.shared.drain(for: friend.userId)
                // Defer to next run loop to avoid state update during view update
                DispatchQueue.main.async {
                    for e in pending {
                        NotificationCenter.default.post(name: .friendShakerEmojiReactionAdded, object: nil, userInfo: ["friendUserId": friend.userId, "emoji": e])
                    }
                    // If there is a pending text note, trigger the note emoji add
                    if PendingNoteStore.shared.consume(for: friend.userId) {
                        NotificationCenter.default.post(name: .friendShakerNoteAdded, object: nil, userInfo: ["friendUserId": friend.userId])
                    }
                }
                // Re-check if current user has left a note (to update button visibility)
                Task { await checkIfUserLeftTextNote() }
                // Refresh any-notes state for disabling the view-notes action
                Task { await refreshHasAnyNotes() }
            }
        }
        .onDisappear {
            if let token = emojiObserver {
                NotificationCenter.default.removeObserver(token)
                emojiObserver = nil
            }
        }
        .overlay {
            if showingNoteSheet {
                ZStack(alignment: .center) {
                    // Dark blur overlay covering entire screen
                    ZStack {
                        DarkBlurView(style: .systemUltraThinMaterialDark)
                            .ignoresSafeArea()
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                    }
                    .contentShape(Rectangle())
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingNoteSheet = false
                        }
                    }

                    // Centered note composer
                    LeaveNoteSheet(friend: friend, onClose: { showingNoteSheet = false })
                        .transition(.opacity)
                        .zIndex(1)
                }
                .ignoresSafeArea(.all)
                .zIndex(1000)
                .animation(.easeInOut(duration: 0.2), value: showingNoteSheet)
            }
        }
        .fullScreenCover(isPresented: $showingNotesPopup) {
            NotesPopupView(
                friend: friend,
                initialNoteId: selectedNoteId,
                initialNoteContent: selectedNoteContent,
                initialNote: selectedNote,
                date: friendTaskViewModel.taskSelectedDate
            )
            .id(selectedNoteId ?? UUID())
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerNoteAdded)) { notification in
            if let friendUserId = notification.userInfo?["friendUserId"] as? String,
               friendUserId == friend.userId {
                hasLeftTextNote = true
                hasAnyNotes = true
            }
        }
        // On emoji reaction (could be like or emoji-note), refresh from DB to determine if any notes exist for TODAY
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerEmojiReactionAdded)) { notification in
            if let fid = notification.userInfo?["friendUserId"] as? String,
               fid == friend.userId {
                Task {
                    await checkIfUserLeftTextNote()
                    await refreshHasAnyNotes()
                }
            }
        }
        // On reaction removal, recompute from DB to decide if any notes remain
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerEmojiReactionRemoved)) { _ in
            Task { await refreshHasAnyNotes() }
        }
        // When selected date changes in the task VM, refresh notes presence
        .onReceive(friendTaskViewModel.$taskSelectedDate) { _ in
            Task { await refreshHasAnyNotes() }
        }
        .task {
            await checkIfUserLeftTextNote()
            await refreshHasAnyNotes()
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
                HStack(spacing: 8) {
                    // Toggle between Calendar and Shaker
                    Button(action: { showingCalendar.toggle() }) {
                        Group {
                            if showingCalendar {
                                Image("jar_icon")
                                    .resizable()
                                    .renderingMode(.original)
                            } else {
                                Image("calendar")
                                    .resizable()
                                    .renderingMode(.original)
                            }
                        }
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
                            communityViewModel.addFriendToFavoritesById(friendId: friend.userId)
                        } else {
                            communityViewModel.removeFriendFromFavoritesById(friendId: friend.userId)
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
    }
    
    private var leaveNoteButton: some View {
        Button(action: { showingNoteSheet = true }) {
            Text("Leave a Note")
                .foregroundColor(AppColors.neutral1000)
                .appFont(AppFont.title3Semibold)
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
    
    @State private var selectedNoteId: UUID? = nil
    @State private var selectedNoteContent: String? = nil
    @State private var selectedNote: NoteRecord? = nil
    private func showNotesPopup(_ note: NoteRecord) {
        selectedNoteId = note.id
        selectedNoteContent = note.noteContent
        selectedNote = note
        showingNotesPopup = true
    }
    
    private func checkIfUserLeftTextNote() async {
        guard let currentUserId = getUserId(),
              let userId = UUID(uuidString: currentUserId) else {
            return
        }
        do {
            if let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId) {
                // Treat ANY note (text OR emoji OR both) as having left a note
                let has = try await CommunityService().userHasAnyNote(shakerId: shakerId, userId: userId)
                await MainActor.run {
                    self.hasLeftTextNote = has
                }
            } else {
            }
        } catch {
        }
    }

    private func refreshHasAnyNotes() async {
        do {
            if let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId) {
                let loaded = try await CommunityService().getNotesForShaker(shakerId: shakerId, limit: 1)
                await MainActor.run { self.hasAnyNotes = !loaded.isEmpty }
            } else {
                await MainActor.run { self.hasAnyNotes = false }
            }
        } catch {
            await MainActor.run { self.hasAnyNotes = false }
        }
    }
}


