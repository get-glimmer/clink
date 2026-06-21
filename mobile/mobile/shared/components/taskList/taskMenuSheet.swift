import SwiftUI

struct TaskMenuOverlay: View {
    let task: TaskListItem
    let viewModel: TaskListViewModel
    let onClose: () -> Void

    @State private var backdropVisible = false
    @State private var sheetVisible = false
    @State private var sheetLift: CGFloat = 0

    private var holder: CategoryWithTasks? {
        viewModel.categoriesWithTasks.first { $0.tasks.contains { $0.id == task.id } }
    }

    private var isArchivedTask: Bool {
        holder?.category.type == .archived
    }

    private var dailyCategories: [CategoryItem] {
        viewModel.categoriesWithTasks
            .filter { $0.category.type == .daily }
            .map { $0.category }
    }

    private var archivedCategories: [CategoryItem] {
        viewModel.categoriesWithTasks
            .filter { $0.category.type == .archived }
            .map { $0.category }
    }

    private var menuHeight: CGFloat {
        isArchivedTask ? 275 : 340
    }

    private var isDueToday: Bool {
        task.dueDate.map { Calendar.current.isDateInToday($0) } ?? false
    }

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    var body: some View {
        GeometryReader { proxy in
            let sheetHeight = menuHeight + proxy.safeAreaInsets.bottom
            let sheetWidth = UIScreen.main.bounds.width + 2
            let horizontalOverflow = max(0, sheetWidth - proxy.size.width)

            ZStack(alignment: .bottom) {
                // Standard repo modal backdrop: dark blur plus dim layer.
                ZStack {
                    DarkBlurView(style: .systemUltraThinMaterialDark)
                        .ignoresSafeArea()

                    Color.black.opacity(0)
                        .ignoresSafeArea()
                }
                .opacity(backdropVisible ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }

                TaskMenuSheet(
                    taskTitle: task.title,
                    isDueToday: isDueToday,
                    initialDueDate: task.dueDate,
                    isArchivedTask: isArchivedTask,
                    dailyCategories: dailyCategories,
                    archivedCategories: archivedCategories,
                    onDoToday: {
                        Task { await viewModel.updateTaskDate(taskId: task.id, newDate: Date()) }
                        dismiss()
                    },
                    onDoTomorrow: {
                        Task { await viewModel.updateTaskDate(taskId: task.id, newDate: tomorrow) }
                        dismiss()
                    },
                    onConfirmChangeDate: { picked in
                        Task { await viewModel.updateTaskDate(taskId: task.id, newDate: picked) }
                        dismiss()
                    },
                    onMakeRoutine: {
                    },
                    onDelete: {
                        Task { await viewModel.deleteTask(task: task) }
                        dismiss()
                    },
                    onArchiveToCategory: { selected in
                        Task { await viewModel.moveTaskToCategory(taskId: task.id, toCategoryId: selected.id) }
                        dismiss()
                    },
                    onReassignToDaily: { selectedDaily in
                        Task { await viewModel.moveTaskToCategory(taskId: task.id, toCategoryId: selectedDaily.id) }
                    },
                    onEditTitle: { newTitle in
                        Task { await viewModel.updateTaskTitle(taskId: task.id, newTitle: newTitle) }
                    },
                    viewModel: viewModel,
                    baseRoutineCategory: holder?.category
                )
                .frame(width: sheetWidth, height: sheetHeight)
                .offset(x: -horizontalOverflow / 2, y: sheetVisible ? -sheetLift : sheetHeight)
                .ignoresSafeArea(edges: .bottom)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 0.18)) {
                    backdropVisible = true
                }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.92)) {
                    sheetVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                // Distance from the sheet's top edge down to the bottom of the title field
                // (grabber top padding + grabber + header top padding + title field height),
                // plus a small margin so the field sits clearly above the keyboard.
                let titleFieldBottomInset: CGFloat = 70
                let margin: CGFloat = 12
                // Lift only enough for the title field to clear the keyboard's top edge.
                let lift = max(0, frame.height + titleFieldBottomInset + margin - sheetHeight)
                withAnimation(.easeOut(duration: 0.25)) {
                    sheetLift = lift
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    sheetLift = 0
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.14)) {
            backdropVisible = false
        }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.96)) {
            sheetVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onClose()
        }
    }
}

struct TaskMenuSheet: View {
    // MARK: - Inputs (state from parent)
    let taskTitle: String
    let isDueToday: Bool
    let initialDueDate: Date?
    let isArchivedTask: Bool
    let dailyCategories: [CategoryItem]
    let archivedCategories: [CategoryItem]
    let viewModel: TaskListViewModel?
    let baseRoutineCategory: CategoryItem?
    
    // Actions from parent
    var onDoToday: () -> Void = {}
    var onDoTomorrow: () -> Void = {}
    var onConfirmChangeDate: (Date) -> Void = { _ in }
    var onMakeRoutine: () -> Void = {}
    var onDelete: () -> Void = {}
    
    // Category change hooks
    var onArchiveToCategory: (CategoryItem) -> Void = { _ in }
    var onReassignToDaily: (CategoryItem) -> Void = { _ in }
    
    // routines
    @State private var showAddRoutineOverlay: Bool = false
    @State private var routineCategory: CategoryItem? = nil
    
    // Title edit commit
    var onEditTitle: (String) -> Void = { _ in }

    // MARK: - Local UI states
    // Title edit
    @State private var currentTitle: String
    @State private var isEditingTitle: Bool = false
    @State private var titleDraft: String
    @FocusState private var titleFieldFocused: Bool
    
    // Overlays
    @State private var showChangeDateOverlay: Bool = false
    @State private var showChooseArchivedOverlay: Bool = false
    @State private var showChooseDailyOverlay: Bool = false
    
    // archived → daily 전환 이후 실행할 pending action
    private enum PendingAction { case doToday, doTomorrow, changeDate, makeRoutine }
    @State private var pendingAction: PendingAction? = nil
    
    // Init
    init(
        taskTitle: String,
        isDueToday: Bool,
        initialDueDate: Date?,
        isArchivedTask: Bool,
        dailyCategories: [CategoryItem],
        archivedCategories: [CategoryItem],
        onDoToday: @escaping () -> Void = {},
        onDoTomorrow: @escaping () -> Void = {},
        onConfirmChangeDate: @escaping (Date) -> Void = { _ in },
        onMakeRoutine: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {},
        onArchiveToCategory: @escaping (CategoryItem) -> Void = { _ in },
        onReassignToDaily: @escaping (CategoryItem) -> Void = { _ in },
        onEditTitle: @escaping (String) -> Void = { _ in },
        viewModel: TaskListViewModel? = nil,
        baseRoutineCategory: CategoryItem? = nil
    ) {
        self.taskTitle = taskTitle
        self.isDueToday = isDueToday
        self.initialDueDate = initialDueDate
        self.isArchivedTask = isArchivedTask
        self.dailyCategories = dailyCategories
        self.archivedCategories = archivedCategories
        self.onDoToday = onDoToday
        self.onDoTomorrow = onDoTomorrow
        self.onConfirmChangeDate = onConfirmChangeDate
        self.onMakeRoutine = onMakeRoutine
        self.onDelete = onDelete
        self.onArchiveToCategory = onArchiveToCategory
        self.onReassignToDaily = onReassignToDaily
        self.onEditTitle = onEditTitle
        self.viewModel = viewModel
        self.baseRoutineCategory = baseRoutineCategory
        _routineCategory = State(initialValue: baseRoutineCategory)
        _currentTitle = State(initialValue: taskTitle)
        _titleDraft   = State(initialValue: taskTitle)
    }
    
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
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                grabber
                    .padding(.top, 9)
                header
                Divider()
                    .background(Color("Neutral-800"))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                options
                    .padding(.top, 18)
                    .padding(.leading, 22)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        
        // MARK: ChangeDateSheet overlay
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
        
        // MARK: Choose Archived Category (daily → archived)
        .fullScreenCover(isPresented: $showChooseArchivedOverlay) {
            ChooseArchivedCategorySheet(
                archivedCategories: archivedCategories,
                onSelect: { cat in
                    onArchiveToCategory(cat)
                    showChooseArchivedOverlay = false
                },
                onCancel: { showChooseArchivedOverlay = false }
            )
            .transition(.opacity)
            .ignoresSafeArea()
        }
        // MARK: Choose Daily Category (archived → daily)
        .fullScreenCover(isPresented: $showChooseDailyOverlay) {
            ChooseDailyCategorySheet(
                dailyCategories: dailyCategories,
                onSelect: { cat in
                    // 1) Change category first
                    onReassignToDaily(cat)
                    // 2) Continue with pending action
                    switch pendingAction {
                    case .doToday:    onDoToday()
                    case .doTomorrow: onDoTomorrow()
                    case .changeDate: showChangeDateOverlay = true
                    case .makeRoutine:
                           routineCategory = cat
                           showAddRoutineOverlay = true
                    case .none: break
                    }
                    pendingAction = nil
                    showChooseDailyOverlay = false
                },
                onCancel: {
                    pendingAction = nil
                    showChooseDailyOverlay = false
                }
            )
            .transition(.opacity)
            .ignoresSafeArea()
        }
        // MARK: AddRoutineSheet overlay
        .fullScreenCover(isPresented: $showAddRoutineOverlay) {
            if let vm = viewModel, let cat = routineCategory {
                AddRoutineSheet(
                    category: cat,
                    viewModel: vm,
                    initialTitle: currentTitle
                )
                .ignoresSafeArea()
                .transition(.opacity)
            } else {
                Color.clear.onAppear { showAddRoutineOverlay = false }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showChangeDateOverlay)
        .animation(.easeInOut(duration: 0.22), value: showChooseArchivedOverlay)
        .animation(.easeInOut(duration: 0.22), value: showChooseDailyOverlay)
        .animation(.easeInOut(duration: 0.22), value: showAddRoutineOverlay)
    }
    
    // MARK: - grabber
    private var grabber: some View {
        Rectangle()
            .foregroundColor(.clear)
            .frame(width: 44, height: 3)
            .background(.neutral800)
            .cornerRadius(2)
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
                if isEditingTitle {
                    commitTitleChange()
                } else {
                    titleDraft = currentTitle
                    isEditingTitle = true
                    DispatchQueue.main.async { titleFieldFocused = true }
                }
            } label: {
                Image("pencil")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 15)
            
            // --- Delete button ---
            Button(action: onDelete) {
                Image("trashcan")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
            .padding(.top, 20)
            .padding(.leading, 30)
            .padding(.trailing, 25)
    }
    
    // MARK: - Options
    private var options: some View {
        return VStack(spacing: 16) {
            // Do it Today / Tomorrow
            if isDueToday {
                optionRow(assetIcon: "arrowRight", title: "Do it Tomorrow") {
                    if isArchivedTask {
                        pendingAction = .doTomorrow
                        showChooseDailyOverlay = true
                    } else {
                        onDoTomorrow()
                    }
                }
            } else {
                optionRow(assetIcon: "arrowDown", title: "Do it Today") {
                    if isArchivedTask {
                        pendingAction = .doToday
                        showChooseDailyOverlay = true
                    } else {
                        onDoToday()
                    }
                }
            }
            
            // Change Date
            optionRow(assetIcon: "arrowsCircular", title: "Change Date") {
                if isArchivedTask {
                    pendingAction = .changeDate
                    showChooseDailyOverlay = true
                } else {
                    showChangeDateOverlay = true
                }
            }
            
            // Make it a Routine
            optionRow(assetIcon: "clock", title: "Make it a Routine") {
                if isArchivedTask {
                    pendingAction = .makeRoutine
                    showChooseDailyOverlay = true
                } else {
                    routineCategory = baseRoutineCategory
                    showAddRoutineOverlay = true 
                }
            }
            
            // Archive a Task (hidden on archived tasks)
            if !isArchivedTask {
                optionRow(assetIcon: "folder", title: "Archive a Task") {
                    showChooseArchivedOverlay = true
                }
            }
        }
    }
    
    // MARK: - Row factory
    @ViewBuilder
    private func optionRow(
        systemIcon: String? = nil,
        assetIcon: String? = nil,
        title: String,
        action: @escaping () -> Void,
        isDisabled: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.neutral800)
                        .frame(width: 44, height: 44)
                    iconView(systemIcon: systemIcon, assetIcon: assetIcon)
                }
                Text(title)
                    .appFont(AppFont.labelL)
                    .foregroundColor(Color("White"))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    // // MARK: -iconView
    @ViewBuilder
    private func iconView(systemIcon: String?, assetIcon: String?) -> some View {
        if let asset = assetIcon {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(Color("White"))
        } else if let sys = systemIcon {
            Image(systemName: sys)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("White"))
        }
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
        onEditTitle(trimmed)
        currentTitle = trimmed
        titleFieldFocused = false
        isEditingTitle = false
    }
}
