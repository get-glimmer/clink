import SwiftUI

struct TaskMenuSheet: View {
    let taskTitle: String
    let isDueToday: Bool
    let initialDueDate: Date?

    var onDoToday: () -> Void = {}
    var onDoTomorrow: () -> Void = {}
    var onChangeDate: () -> Void = {}
    var onConfirmChangeDate: (Date) -> Void = { _ in }
    var onMakeRoutine: () -> Void = {}
    var onArchive: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onSubmitTitle: (String) -> Void = { _ in }
    
    // Edit state
    @State private var currentTitle: String
    @State private var isEditingTitle: Bool = false
    @State private var titleDraft: String
    @FocusState private var titleFieldFocused: Bool
    
    // --- change date overlay state ---
        @State private var showChangeDateOverlay: Bool = false
    
    // Ensure initial text matches sheet input
    init(
        taskTitle: String,
        isDueToday: Bool,
        initialDueDate: Date?,
        onDoToday: @escaping () -> Void = {},
        onDoTomorrow: @escaping () -> Void = {},
        onChangeDate: @escaping () -> Void = {},
        onConfirmChangeDate: @escaping (Date) -> Void = { _ in },
        onMakeRoutine: @escaping () -> Void = {},
        onArchive: @escaping () -> Void = {},
        onEdit: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {},
        onSubmitTitle: @escaping (String) -> Void = { _ in }
    ) {
        self.taskTitle = taskTitle
        self.isDueToday = isDueToday
        self.initialDueDate = initialDueDate
        self.onDoToday = onDoToday
        self.onDoTomorrow = onDoTomorrow
        self.onChangeDate = onChangeDate
        self.onConfirmChangeDate = onConfirmChangeDate
        self.onMakeRoutine = onMakeRoutine
        self.onArchive = onArchive
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onSubmitTitle = onSubmitTitle
        _titleDraft   = State(initialValue: taskTitle)
        _currentTitle = State(initialValue: taskTitle)
    }

    var body: some View {
        VStack(spacing: 0) {
            // --- Header ---
            header
            
            // --- Divider ---
            Divider()
                .frame(width: 361)
                .background(Color("Neutral-800"))
                .padding(.top, 16)

            // --- Options ---
            options
        }
        .presentationDragIndicator(.visible)

        // ── ChangeDateSheet overlay ────────────────────────────
        .fullScreenCover(isPresented: $showChangeDateOverlay) {
            if showChangeDateOverlay {
                ChangeDateSheet(
                    initialDate: initialDueDate ?? Date(),
                    onConfirm: { picked in
                        onConfirmChangeDate(picked)
                        showChangeDateOverlay = false
                    },
                    onCancel: {
                        showChangeDateOverlay = false
                    }
                )
                .transition(.opacity)
                .ignoresSafeArea()
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showChangeDateOverlay)
    }
    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center) {
            // Title
            if isEditingTitle {
                TextField("Task title", text: $titleDraft)
                    .appFont(AppFont.title3)
                    .foregroundColor(Color("White"))
                    .submitLabel(.done)
                    .focused($titleFieldFocused)
                    .onAppear {
                        DispatchQueue.main.async { titleFieldFocused = true }
                    }
                    .onSubmit { commitTitleChange() }
            } else {
                Text(currentTitle)
                    .appFont(AppFont.title3)
                    .foregroundColor(Color("White"))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
            
            // --- Edit button ---
            Button {
                onEdit()
                if isEditingTitle {
                    commitTitleChange()
                } else {
                    titleDraft = currentTitle
                    isEditingTitle = true
                    DispatchQueue.main.async { titleFieldFocused = true }
                }
            } label: {
                Image("pencil")
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)

            // --- Delete button ---
            Button(action: onDelete) {
                Image("trashcan")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    // MARK: - Options
    private var options: some View {
        VStack(spacing: 20) {
            if isDueToday {
                optionRow(systemIcon: "arrow.right",
                          title: "Do it Tomorrow",
                          action: onDoTomorrow)
            } else {
                optionRow(systemIcon:
                            "arrow.down",
                          title: "Do it Today",
                          action: onDoToday)
            }

            optionRow(
                systemIcon: "arrow.trianglehead.2.counterclockwise.rotate.90",
                title: "Change Date",
                action: {
                    onChangeDate()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showChangeDateOverlay = true
                    }
                }
            )
            optionRow(
                systemIcon: "clock.arrow.circlepath",
                title: "Make it a Routine",
                action: onMakeRoutine
            )
            optionRow(
                systemIcon: "folder",
                title: "Archive a Task",
                action: onArchive
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
    }

    // MARK: - Row factory
    @ViewBuilder
    private func optionRow(systemIcon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {

                ZStack {
                    Circle()
                        .fill(Color("Green-300"))
                        .frame(width: 44, height: 44)
                    Image(systemName: systemIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("White"))
                }

                Text(title)
                    .appFont(AppFont.labelM)
                    .foregroundColor(Color("White"))

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Title commit
    private func commitTitleChange() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != taskTitle else {
            // Exit edit mode without update if empty or unchanged
            isEditingTitle = false
            titleFieldFocused = false
            return
        }
        onSubmitTitle(trimmed)
        currentTitle = trimmed
        titleFieldFocused = false
        isEditingTitle = false
    }
}
