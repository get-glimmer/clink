//
//  TaskListView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI
import Combine

struct TaskListView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @State private var editingTexts: [UUID: String] = [:]
    @FocusState private var focusedTaskId: UUID?
    
    // temporary row privacy toggle state (true = user_only)
    @State private var editingPrivacyOn: [UUID: Bool] = [:]
    
    // task menu sheet state
    @Binding var activeTask: TaskListItem?
    
    // used so that fetchCategoriesAndTasks() can fetch data at wanted date
    @Binding var taskSelectedDate: Date
    
    // keyboard-avoid state
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardAnimationDuration: Double = 0.25
  
    // now accepts a binded date as a parameter
    init(taskSelectedDate: Binding<Date>, viewModel: TaskListViewModel, activeTask: Binding<TaskListItem?>) {
        self._taskSelectedDate = taskSelectedDate
        self.viewModel = viewModel
        self._activeTask = activeTask
    }
    
    // MARK: - Main View
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        dailyTaskHeader
                        dailyCategoriesSection
                        archivedTaskHeader
                        archivedCategoriesSection
                    }
                    .padding(.bottom, 120) // breathing room at end of list (sheet itself lifts for the keyboard)
                    // Fill the viewport so empty space below the list is still
                    // tappable, and make any tap on that empty space cancel the
                    // in-progress new task (rows / the temp field keep their own
                    // gestures, so tapping them is unaffected).
                    .frame(minHeight: geo.size.height, alignment: .top)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.hasTemporaryTask {
                            viewModel.cancelTemporaryTasks()
                            focusedTaskId = nil
                        }
                    }
                }
                .onChange(of: focusedTaskId) { newValue in // auto-scroll to focused input
                    scrollToFocusedTask(proxy: proxy)
                }
                .onChange(of: keyboardHeight) { _ in // re-scroll once the keyboard height is known
                    scrollToFocusedTask(proxy: proxy)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard
                let userInfo = note.userInfo,
                let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
                let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            else { return }
            keyboardAnimationDuration = duration
            // Convert to local coordinates
            let screen = UIScreen.main.bounds
            let overlap = max(0, screen.maxY - endFrame.minY)
            withAnimation(.easeInOut(duration: duration)) {
                keyboardHeight = overlap
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
            let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            withAnimation(.easeInOut(duration: duration)) {
                keyboardHeight = 0
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // Scrolls the focused task into a comfortable position above the keyboard.
    // Runs on both focus changes and keyboard-height changes so the new-task
    // field is brought into view even when the keyboard reports its size after
    // the field appears (otherwise a near-bottom row stays hidden underneath it).
    private func scrollToFocusedTask(proxy: ScrollViewProxy) {
        guard let id = focusedTaskId else { return }
        // Scroll twice: once immediately, then again after the sheet's
        // expand animation settles (the sheet grows over ~0.7s as the shaker
        // shrinks, which shifts the row's final resting position).
        for delay in [0.05, 0.55] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard focusedTaskId == id else { return }
                withAnimation(.easeInOut(duration: keyboardAnimationDuration)) {
                    // upper-third anchor keeps the row visible and roughly centered
                    // in the space remaining above the keyboard
                    proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.3))
                }
            }
        }
    }
    
    // MARK: - Headers
    private var dailyTaskHeader: some View {
        HStack {
            Text("Daily Task")
                .font(.headline)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 4)
    }
    private var archivedTaskHeader: some View {
        HStack {
            Text("Archived Task")
                .font(.headline)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 4)
    }

    // MARK: - Sections
    private var dailyCategoriesSection: some View {
        ForEach(viewModel.categoriesWithTasks.filter { $0.category.type == .daily }) { item in
            categoryCard(for: item)
        }
        .padding(.horizontal)
    }
    private var archivedCategoriesSection: some View {
        ForEach(viewModel.categoriesWithTasks.filter { $0.category.type == .archived }) { item in
            categoryCard(for: item)
        }
        .padding(.horizontal)
    }
    
    // MARK: - categoryCard
    private func categoryCard(for categoryWithTasks: CategoryWithTasks) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .foregroundColor(Color("Neutral-900"))
            VStack(alignment: .leading, spacing: 25) {
                categoryHeader(for: categoryWithTasks)
                tasksSection(for: categoryWithTasks)
            }
            .padding(.top, 22)
            .padding(.horizontal, 19)
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity, minHeight: categoryWithTasks.tasks.isEmpty ? 60 : 120)
        .padding(.vertical, 8)
    }
    
    private func categoryHeader(for categoryWithTasks: CategoryWithTasks) -> some View {
        HStack {
            Text(
                viewModel.emojiFor(
                    categoryId: categoryWithTasks.category.id,
                    defaultEmoji: categoryWithTasks.category.emoji
                )
            )
            .font(.system(size: 27))

            HStack(spacing: 0) {
                Text(categoryWithTasks.category.name)
                    .appFont(AppFont.title3)

                if (categoryWithTasks.category.privacyStatus ?? "public") == "user_only" {
                    Image("privacyOnSmall")
                        .accessibilityLabel("Private category")
                }
            }
            Spacer()
            addTaskButton(for: categoryWithTasks.category.id)
        }
    }

    
    private func addTaskButton(for categoryId: UUID) -> some View {
        Button(action: {
            viewModel.createTemporaryTask(categoryId: categoryId)
        }) {
            Image(systemName: "plus")
                .imageScale(.large)
                .frame(width: 27, height: 27)
                .foregroundColor(.primary)
        }
        // Only one new task may be created at a time.
        .disabled(viewModel.hasTemporaryTask)
        .opacity(viewModel.hasTemporaryTask ? 0.3 : 1)
    }
    
    private func tasksSection(for categoryWithTasks: CategoryWithTasks) -> some View {
        ForEach(categoryWithTasks.tasks) { task in
            taskRow(for: task)
                .padding(.leading, 2.84)
                .padding(.trailing, 0.4)
                .id(task.id)
        }
    }
    
    //MARK: task row
    private func taskRow(for task: TaskListItem) -> some View {
        HStack(spacing: 0) {
            taskCheckbox(for: task)
            taskContent(for: task)
                .padding(.leading, 13.42)
            
            // lock for private tasks
            if !task.isTemporary && task.privacyStatus == "user_only" {
                Image("privacyOnSmall")
                    .accessibilityLabel("Private task")
            }
            Spacer()
            if task.isTemporary{
                privacyToggleButton(for: task)
            }
            else{
                taskMenuButton(for: task)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if task.isTemporary {
                focusedTaskId = task.id // keep editing the new task
            } else {
                // Tapping a different (real) row discards the in-progress new task.
                viewModel.cancelTemporaryTasks()
                focusedTaskId = nil
            }
        }
    }

    private func taskCheckbox(for task: TaskListItem) -> some View {
        Button(action: {
            if !task.isTemporary {
                viewModel.toggleTaskCompletion(task: task)
            }
        }) {
            Image(task.isCompleted ? "checkboxFilled" : "checkboxEmpty")
                .foregroundColor(.primary)
                .imageScale(.large)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(task.isTemporary)
    }
    
    @ViewBuilder
    private func taskContent(for task: TaskListItem) -> some View {
        if task.isTemporary {
            temporaryTaskField(for: task)
        } else {
            completedTaskText(for: task)
        }
    }
    
    private func temporaryTaskField(for task: TaskListItem) -> some View {
        VStack{
            HStack(spacing: 10) {
                TextField("Type...", text: Binding(
                    get: { editingTexts[task.id] ?? "" },
                    set: { editingTexts[task.id] = $0 }
                ))
                .appFont(AppFont.body1)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($focusedTaskId, equals: task.id)
                .submitLabel(.done)
                .onAppear {
                    editingTexts[task.id] = editingTexts[task.id] ?? ""
                    focusedTaskId = task.id
                    // default OFF (public) when first shown
                    if editingPrivacyOn[task.id] == nil {
                        editingPrivacyOn[task.id] = false
                    }
                }
                .onSubmit {
                    handleTaskSubmit(task: task)
                }
                Spacer()
            }
            .frame(width: 240)
            // underline
            Rectangle()
                .frame(width: 240, height: 1)
                .foregroundColor(Color("Neutral-400"))
        }
    }
    
    private func completedTaskText(for task: TaskListItem) -> some View {
        Text(task.title)
            .appFont(AppFont.body1)
            .strikethrough(task.isCompleted, color: .primary)
            .foregroundColor(.primary)
    }
    
    @ViewBuilder

    private func taskMenuButton(for task: TaskListItem) -> some View {
        Button {
            activeTask = task
            AnalyticsService.shared.trackEvent("task_opened",
                screenName: "Home",
                source: "task_menu",
                properties: ["task_id": task.id.uuidString])
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.primary)
                .imageScale(.medium)
                .frame(width: 25, height: 25)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
    
    private func privacyToggleButton(for task: TaskListItem) -> some View {
        Button {
            editingPrivacyOn[task.id]?.toggle()
        } label: {
            Image((editingPrivacyOn[task.id] ?? false) ? "privacyOn" : "privacyOff")
                .accessibilityLabel("Toggle privacy")
        }
        .buttonStyle(.plain)
    }
    
    private func handleTaskSubmit(task: TaskListItem) {
        let text = (editingTexts[task.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, let categoryId = viewModel.categoryId(forTaskId: task.id) {
            let isPrivate = editingPrivacyOn[task.id] ?? false // default unlocked
            // Remove the temp row up front so the tap-out cancel (which also
            // fires when the keyboard dismisses) can't race with the save.
            viewModel.removeTemporaryTask(task: task)
            Task {
                await viewModel.saveTemporaryTask(categoryId: categoryId, newTitle: text, isPrivate: isPrivate)
            }
        } else {
            viewModel.removeTemporaryTask(task: task)
        }
        editingTexts.removeValue(forKey: task.id)
        editingPrivacyOn.removeValue(forKey: task.id)
        focusedTaskId = nil
    }
}
