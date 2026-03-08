
import SwiftUI

struct TaskView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var shakerRefreshId = UUID()
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
    @State private var selectedNoteId: UUID? = nil
    @State private var selectedNoteContent: String? = nil
    @State private var selectedNote: NoteRecord? = nil
    @State private var activeTaskMenu: TaskListItem? = nil

    init() {
        let userId = getUserId()
        _viewModel = StateObject(wrappedValue: TaskListViewModel(userId: userId, date: todayDate()))
    }

//MARK: - main view
    var body: some View {
        GeometryReader { geo in
            let screenHeight = geo.size.height
            let screenWidth = geo.size.width
            let scale = max(0.4, 1 - 0.6 * sheetProgress)
            let shakerSide = screenWidth * 0.9 * scale
            

            let minSheetHeight = screenHeight/794*340
            let maxSheetHeight = screenHeight/794*560
            
            let shakerIsActive =
              !showOptionsSheet &&
              !showAddCategorySheet &&
              !showCategoriesSheet &&
              !showRoutinesSheet &&
              !showingNotesPopup &&
              !showChangeDateSheet &&
              (sheetProgress == 0)

            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    //MARK: - header
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
                                    Image("optionsButton")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, 16)
                    }
                    .padding(.top, 12)

                    //MARK: - shaker
                    ShakerView(
                        viewModel: viewModel,
                        isActive: shakerIsActive,
                        forceFullMode: true,
                        showStickyNotes: (sheetProgress == 0),
                        onNoteTapped: { note in
                            selectedNoteId = note.id
                            selectedNoteContent = note.noteContent
                            selectedNote = note
                            showingNotesPopup = true
                        }
                    )
                    .id(shakerRefreshId)
                        .frame(width: shakerSide, height: shakerSide)
                        .frame(maxWidth: 275)
                        .padding(.top, 16)
                }

                //MARK: - task list
                BottomSheet(
                    minHeight: minSheetHeight,
                    maxHeight: maxSheetHeight,
                    progress: $sheetProgress
                ) {
                    // --Task List Content--
                    ScrollView {
                        TaskListView(taskSelectedDate: $selectedDate, viewModel: viewModel, activeTask: $activeTaskMenu)
                            .padding(.bottom, 120)
                            //.padding(.top, -6) // for grabber hit area
                    }
                    .coordinateSpace(name: "BottomSheetScroll")
                }
            }
            .animation(.easeInOut, value: scale)
            //MARK: - "Options" popup
            .overlay(alignment: .topTrailing) {
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
                    .transition(.scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity))
                }
            }
            .overlay {
                if let task = activeTaskMenu {
                    TaskMenuOverlay(
                        task: task,
                        viewModel: viewModel,
                        onClose: { activeTaskMenu = nil }
                    )
                    .transition(.identity)
                    .zIndex(2000)
                }
            }
            .zIndex(999)
            .animation(.easeInOut(duration: 0.2), value: showOptionsSheet)
        }
        .background(.neutral1000)
        .ignoresSafeArea(edges: .bottom)
        .navBarHidden(activeTaskMenu != nil)
        .onAppear {
            sheetProgress = 0
            shakerRefreshId = UUID()
            viewModel.fetchCategoriesAndTasks()
            viewModel.taskSelectedDate = selectedDate
        }
        .onChange(of: selectedDate) { newValue in
            viewModel.taskSelectedDate = newValue
            // viewModel.fetchCategoriesAndTasks()
        }
        //MARK: - "Add category" sheet
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
        //MARK: - "Categories" sheet
        .fullScreenCover(isPresented: $showCategoriesSheet) {
            CategoriesSheet(viewModel: viewModel)
        }
        //MARK: -  "Routines" sheet
        .fullScreenCover(isPresented: $showRoutinesSheet) {
            RoutinesSheet(viewModel: viewModel)
        }
        //MARK: -  "Change Date" sheet
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
            SelfNotesPopupView(
                initialNoteId: selectedNoteId,
                initialNoteContent: selectedNoteContent,
                initialNote: selectedNote,
                date: selectedDate
            )
            .id(selectedNoteId ?? UUID())
        }
    }
}
//#Preview {TaskView()}

// MARK: - Self Notes Popup View (for my own jar)
private struct SelfNotesPopupView: View {
    let initialNoteId: UUID?
    let initialNoteContent: String?
    let initialNote: NoteRecord?
    let date: Date
    @State private var notes: [NoteRecord] = []
    @State private var isLoading: Bool = true
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communityService = CommunityService()
    @State private var currentIndex: Int = 0
    @State private var authorNames: [UUID: String] = [:]

    var body: some View {
        ZStack {
            // Background: dark blur + dim
            ZStack {
                DarkBlurView(style: .systemChromeMaterialDark)
                    .ignoresSafeArea()
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
            }
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }

            // Stacked sticky notes with paging (same visual as friend popup)
            GeometryReader { geo in
                let cardW: CGFloat = 320
                let cardH: CGFloat = 320
                let colors: [Color] = [
                    Color(red: 1.00, green: 0.96, blue: 0.66),
                    Color(red: 1.00, green: 0.89, blue: 0.74),
                    Color(red: 0.79, green: 0.90, blue: 0.98),
                    Color(red: 0.92, green: 0.86, blue: 0.96)
                ]
                ZStack {
                    // Close button
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(width: 44, height: 44)
                            }
                        }
                        Spacer()
                    }

                    // Stack
                    ZStack {
                        Rectangle()
                            .fill(colors[(currentIndex + 2) % colors.count].opacity(0.9))
                            .frame(width: cardW * 0.98, height: cardH * 0.98)
                            .rotationEffect(.degrees(-6))
                            .offset(x: -12, y: -8)
                            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                        Rectangle()
                            .fill(colors[(currentIndex + 1) % colors.count].opacity(0.95))
                            .frame(width: cardW, height: cardH)
                            .rotationEffect(.degrees(6))
                            .offset(x: 12, y: 8)
                            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)

                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView().scaleEffect(1.2)
                                Text("Loading notes...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.black.opacity(0.6))
                            }
                            .frame(width: cardW, height: cardH)
                            .background(colors[currentIndex % colors.count])
                            .cornerRadius(2)
                        } else if notes.isEmpty {
                            VStack(spacing: 10) {
                                Text("No notes yet")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black.opacity(0.8))
                            }
                            .frame(width: cardW, height: cardH)
                            .background(colors[currentIndex % colors.count])
                            .cornerRadius(2)
                        } else {
                            let note = notes[currentIndex % notes.count]
                            VStack {
                                HStack {
                                    Text(note.noteContent)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.9))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer(minLength: 0)
                                }
                                Spacer()
                                HStack {
                                    // Emoji bottom-left when present
                                    if let emoji = note.noteEmoji, !emoji.isEmpty {
                                        Text(emoji)
                                            .font(.system(size: 60))
                                            .frame(width: 60, height: 60, alignment: .leading)
                                    }
                                    Spacer()
                                    Text("– \(authorNames[note.userId] ?? "Someone")")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 22)
                            .frame(width: cardW, height: cardH)
                            .background(colors[currentIndex % colors.count])
                            .cornerRadius(2)
                            .gesture(
                                DragGesture(minimumDistance: 20)
                                    .onEnded { value in
                                        if value.translation.width < -30 {
                                            withAnimation(.easeInOut(duration: 0.2)) { currentIndex = (currentIndex + 1) % max(notes.count, 1) }
                                        } else if value.translation.width > 30 {
                                            withAnimation(.easeInOut(duration: 0.2)) { currentIndex = (currentIndex - 1 + notes.count) % max(notes.count, 1) }
                                        }
                                    }
                            )
                        }
                    }
                    .frame(width: cardW, height: cardH)

                    if !isLoading && !notes.isEmpty && notes.count > 1 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) { currentIndex = (currentIndex + 1) % notes.count }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.neutral1000)
                            }
                        }
                        .buttonStyle(.plain)
                        .position(x: geo.size.width - 38, y: geo.size.height / 2) // 22pt from right edge (circle radius 16)
                    }

                    // Left paging arrow
                    if !isLoading && !notes.isEmpty && notes.count > 1 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) { currentIndex = (currentIndex - 1 + notes.count) % notes.count }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.neutral1000)
                            }
                        }
                        .buttonStyle(.plain)
                        .position(x: 38, y: geo.size.height / 2) // 22pt from left edge (circle radius 16)
                    }

                    if !isLoading && !notes.isEmpty && notes.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(0..<notes.count, id: \.self) { idx in
                                Circle()
                                    .fill(idx == currentIndex ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .position(x: geo.size.width / 2, y: (geo.size.height + cardH) / 2 + 18)
                    }
                }
            }
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
                if let shakerId = try await communityService.getCurrentShakerForUser(userId: me, date: date) {
                    // Load more to ensure the selected note is included
                    let loaded = try await communityService.getNotesForShaker(shakerId: shakerId, limit: 100)
                    await MainActor.run {
                        let textNotes = loaded.filter { !$0.noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        // Restore multiple notes (up to 10), no special reordering
                        notes = Array(textNotes.prefix(10))
                        currentIndex = 0
                        isLoading = false
                    }
                    // Load author display names for the notes shown
                    let userIds = loaded
                        .filter { !$0.noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .map { $0.userId }
                    await loadAuthorNames(for: userIds)
                } else {
                    await MainActor.run { notes = []; isLoading = false }
                }
            } catch {
                await MainActor.run { notes = []; isLoading = false }
            }
        }
    }
    
    // Load display names for note authors (same behavior as friend notes popup)
    private func loadAuthorNames(for userIds: [UUID]) async {
        guard let client = SupabaseClientManager.shared.client else { return }
        let unique = Array(Set(userIds))
        guard !unique.isEmpty else { return }
        struct Row: Decodable { let id: String; let name: String? }
        do {
            let rows: [Row] = try await client
                .from("profiles")
                .select("id,name")
                .in("id", value: unique.map { $0.uuidString })
                .execute()
                .value
            var map: [UUID: String] = [:]
            for r in rows {
                if let uuid = UUID(uuidString: r.id), let name = r.name {
                    map[uuid] = name
                }
            }
            await MainActor.run { authorNames.merge(map) { _, new in new } }
        } catch {
            // ignore lookup failures
        }
    }
}
