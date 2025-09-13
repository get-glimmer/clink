
import SwiftUI

struct TaskView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var sheetProgress: CGFloat = 0
    @State private var showingNotesPopup: Bool = false
    
    // --- date selection ---
    //@State private var today: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var showChangeDateSheet: Bool = false
    
    private var monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.setLocalizedDateFormatFromTemplate("MMMM d") // ex. July 2
        return f
    }()
    
    // --- options & sheet states ---
    @State private var showOptionsSheet: Bool = false
    
    // 1. Add Category
    @State private var showAddCategorySheet: Bool = false
    @State private var newCategoryEmoji: String = ""
    @State private var newCategoryName: String = ""
    @State private var isSavingCategory: Bool = false
    @State private var categorySaveError: String? = nil
    
    // 2. Categories
    @State private var showCategoriesSheet: Bool = false
    
    // 3. Routines
    @State private var showRoutinesSheet: Bool = false

    init() {
        let userId = getUserId()
        _viewModel = StateObject(wrappedValue: TaskListViewModel(userId: userId, date: todayDate()))
    }


    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width*0.9
            let scale = max(0.4, 1 - 0.6 * sheetProgress)
            let shakerSide = fullWidth * scale

            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    // ---- Header ----
                    ZStack {
                        // Center: Date controls
                        HStack(spacing: 20) {

                            // 1) Previous day
                            Button {
                                if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDate = prev
                                    }
                                    viewModel.taskSelectedDate = prev
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color("Neutral-400"))
                            }
                            .buttonStyle(.plain)

                            // 2) Open calendar sheet (date text)
                            Button {
                                showChangeDateSheet = true
                            } label: {
                                Text(monthDayFormatter.string(from: selectedDate))
                                    .appFont(AppFont.title2)
                                    .foregroundColor(Color("White"))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            // 3) Next day
                            Button {
                                if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDate = next
                                    }
                                    viewModel.taskSelectedDate = next
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color("Neutral-400"))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Right: option button
                        HStack {
                            Spacer()
                            Button {
                                showOptionsSheet = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color("Neutral-900"))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color("Neutral-400"))
                                }
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, 16)
                    }

                    // ---- Shaker (scaled) ----
                    ShakerView(
                        viewModel: viewModel,
                        onNoteEmojiTapped: { showingNotesPopup = true }
                    )
                        .frame(width: shakerSide, height: shakerSide)
                        .frame(maxWidth: 275)
                        .padding(.top, 16)
                }

                // ---- Bottom Sheet ----
                BottomSheet(
                    minHeight: 340,
                    maxHeight: 560,
                    progress: $sheetProgress
                ) {
                    // --Task List Content--
                    ScrollView {
//                        Text("Daily Task")
//                            .font(.headline)
//                            .frame(maxWidth: 340, alignment: .leading)
                        TaskListView(taskSelectedDate: $selectedDate, viewModel: viewModel)
                            .padding(.bottom, 120)
                    }
                }
            }
            .animation(.easeInOut, value: scale)
            // --- "Options" sheet overlay ---
            .overlay(alignment: .bottomLeading) {
                if showOptionsSheet {
                    OptionsSheet(
                        onTapOutside: { showOptionsSheet = false },

                        onTapRoutines: {
                            showOptionsSheet = false
                            showRoutinesSheet = true
                        },

                        onTapCategories: {
                            showOptionsSheet = false
                            showCategoriesSheet = true
                        },

                        onTapAddCategory: {
                            showOptionsSheet = false
                            // Reset inputs and open AddCategorySheet
                            newCategoryEmoji = ""
                            newCategoryName = ""
                            showAddCategorySheet = true
                        }
                    )
                    .transition(.opacity)
                    .ignoresSafeArea()
                }
            }
            .zIndex(999)
            .animation(.easeInOut(duration: 0.25), value: showOptionsSheet)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            viewModel.fetchCategoriesAndTasks()
            viewModel.taskSelectedDate = selectedDate
        }
        .onChange(of: selectedDate) { newValue in
            viewModel.taskSelectedDate = newValue
            // viewModel.fetchCategoriesAndTasks()
        }
        // -- "Add category" sheet --
        .fullScreenCover(isPresented: $showAddCategorySheet) {
            AddCategorySheet(
                emoji: $newCategoryEmoji,
                name: $newCategoryName,
                isSaving: $isSavingCategory,
                errorMessage: $categorySaveError,
                onSave: { emoji, name, privacy, type in
                    isSavingCategory = true
                    Task {
                        do {
                            try? await viewModel.addCategory(
                                name: name,
                                emoji: emoji,
                                privacyStatus: privacy,
                                type: type
                            )
                            isSavingCategory = false
                            showAddCategorySheet = false
                        }
                    }
                }
            )
        }
        // -- "Categories" sheet --
        .fullScreenCover(isPresented: $showCategoriesSheet) {
            CategoriesSheet(viewModel: viewModel)
        }
        // -- "Routines" sheet --
        .fullScreenCover(isPresented: $showRoutinesSheet) {
            RoutinesSheet(viewModel: viewModel)
        }
        // -- "Change Date" sheet --
        .overlay(alignment: .bottomLeading) {
            if showChangeDateSheet {
                ChangeDateSheet(
                    initialDate: selectedDate,
                    onConfirm: { picked in
                        selectedDate = picked
                        viewModel.taskSelectedDate = picked
                        showChangeDateSheet = false
                    },
                    onCancel: { showChangeDateSheet = false }
                )
                .transition(.opacity)
                .ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showChangeDateSheet)
        // Notes popup for my own jar
        .fullScreenCover(isPresented: $showingNotesPopup) {
            SelfNotesPopupView()
        }
    }
}
//#Preview {TaskView()}

// MARK: - Self Notes Popup View (for my own jar)
private struct SelfNotesPopupView: View {
    @State private var notes: [NoteRecord] = []
    @State private var isLoading: Bool = true
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communityService = CommunityService()

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                HStack {
                    Text("Notes for Today")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.neutral800)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.neutral600)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.2)
                        Text("Loading notes...")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.neutral600)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else if notes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.neutral400)
                        Text("No notes yet")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.neutral600)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else {
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
        .onAppear { loadNotes() }
    }

    private func loadNotes() {
        Task {
            isLoading = true
            do {
                guard let me = getUserId() else {
                    isLoading = false; notes = []; return
                }
                if let shakerId = try await communityService.getCurrentShakerForUser(userId: me, date: Date()) {
                    let loaded = try await communityService.getNotesForShaker(shakerId: shakerId, limit: 20)
                    await MainActor.run {
                        let textNotes = loaded.filter { !$0.noteContent.isEmojiOnly }
                        notes = textNotes.randomElement().map { [$0] } ?? []
                        isLoading = false
                    }
                } else {
                    await MainActor.run { notes = []; isLoading = false }
                }
            } catch {
                await MainActor.run { notes = []; isLoading = false }
            }
        }
    }
}
