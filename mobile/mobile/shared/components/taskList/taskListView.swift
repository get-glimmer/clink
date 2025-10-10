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
    @State private var activeTask: TaskListItem? = nil
    
    // used so that fetchCategoriesAndTasks() can fetch data at wanted date
    @Binding var taskSelectedDate: Date
    
    // keyboard-avoid state
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardAnimationDuration: Double = 0.25
  
    // now accepts a binded date as a parameter
    init(taskSelectedDate: Binding<Date>, viewModel: TaskListViewModel) {
        self._taskSelectedDate = taskSelectedDate
        self.viewModel = viewModel
    }
    
    // MARK: - Main View
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    dailyTaskHeader
                    dailyCategoriesSection
                    archivedTaskHeader
                    archivedCategoriesSection
                }
                .padding(.bottom, keyboardHeight)
            }
            .onChange(of: focusedTaskId) { newValue in // auto-scroll to focused input
                guard let id = newValue else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: keyboardAnimationDuration)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
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
        // MARK: Task Menu Sheet
        .sheet(item: $activeTask, onDismiss: { activeTask = nil }) { task in
            let isToday: Bool = task.dueDate.map { Calendar.current.isDateInToday($0) } ?? false
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            
            let holder = viewModel.categoriesWithTasks.first { $0.tasks.contains { $0.id == task.id } }
            let isArchivedTask = (holder?.category.type == .archived)
            
            let dailyCats    = viewModel.categoriesWithTasks.filter { $0.category.type == .daily }.map { $0.category }
            let archivedCats = viewModel.categoriesWithTasks.filter { $0.category.type == .archived }.map { $0.category }
            
            let menuHeight: CGFloat = isArchivedTask ? 317 : 380
            
            TaskMenuSheet(
                taskTitle: task.title,
                isDueToday: isToday,
                initialDueDate: task.dueDate,

                isArchivedTask: isArchivedTask,
                dailyCategories: dailyCats,
                archivedCategories: archivedCats,
                
                // actions
                onDoToday: {
                    Task { await viewModel.updateTaskDate(taskId: task.id, newDate: Date()) }
                    activeTask = nil
                },
                onDoTomorrow: {
                    Task { await viewModel.updateTaskDate(taskId: task.id, newDate: tomorrow) }
                    activeTask = nil
                },
                onConfirmChangeDate: { picked in
                    Task { await viewModel.updateTaskDate(taskId: task.id, newDate: picked) }
                    activeTask = nil
                },
                onMakeRoutine: {
                },
                onDelete: {
                    Task { await viewModel.deleteTask(task: task) }
                    activeTask = nil
                },
                
                onArchiveToCategory: { selected in
                    Task { await viewModel.moveTaskToCategory(taskId: task.id, toCategoryId: selected.id) }
                    activeTask = nil
                },
                onReassignToDaily: { selectedDaily in
                    Task { await viewModel.moveTaskToCategory(taskId: task.id, toCategoryId: selectedDaily.id) }
                    // 이어지는 액션은 TaskMenuSheet 내부에서 pendingAction 으로 처리됨
                },
                
                onEditTitle: { newTitle in
                    Task { await viewModel.updateTaskTitle(taskId: task.id, newTitle: newTitle) }
                },
                viewModel: viewModel,
                baseRoutineCategory: holder?.category  
            )
            .presentationDetents([ .height(menuHeight) ])
            .presentationCornerRadius(24)
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
        .scrollDismissesKeyboard(.interactively)
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
            .padding(.bottom, 30)
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
    }
    
    private func tasksSection(for categoryWithTasks: CategoryWithTasks) -> some View {
        ForEach(categoryWithTasks.tasks) { task in
            taskRow(for: task)
                .padding(.leading, 2.84)
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
            focusedTaskId = nil
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
            Image((editingPrivacyOn[task.id] ?? true) ? "privacyOn" : "privacyOff")
                .accessibilityLabel("Toggle privacy")
        }
        .buttonStyle(.plain)
    }
    
    private func handleTaskSubmit(task: TaskListItem) {
        let text = editingTexts[task.id] ?? ""
        if !text.isEmpty {
            let isPrivate = editingPrivacyOn[task.id] ?? false // default unlocked
            Task {
                await viewModel.saveTemporaryTask(task: task, newTitle: text, isPrivate: isPrivate)
            }
        } else {
            viewModel.removeTemporaryTask(task: task)
        }
        editingTexts.removeValue(forKey: task.id)
        editingPrivacyOn.removeValue(forKey: task.id)
        focusedTaskId = nil
    }
}
