//
//  homeView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI

struct TaskListView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @State private var editingTexts: [UUID: String] = [:]
    @FocusState private var focusedTaskId: UUID?
    
    // task menu sheet state
    @State private var activeTask: TaskListItem? = nil
    
    // used so that fetchCategoriesAndTasks() can fetch data at wanted date
    @Binding var taskSelectedDate: Date
  
    // now accepts a binded date as a parameter
    init(taskSelectedDate: Binding<Date>, viewModel: TaskListViewModel) {
        self._taskSelectedDate = taskSelectedDate
        self.viewModel = viewModel
    }
    
    // MARK: - Main View
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // --- daily section ---
                dailyTaskHeader
                dailyCategoriesSection
                
                // --- archived section ---
                archivedTaskHeader
                archivedCategoriesSection
            }
        }
        .sheet(item: $activeTask, onDismiss: { activeTask = nil }) { task in
            let isToday: Bool = task.dueDate.map { Calendar.current.isDateInToday($0) } ?? false
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            
            let archivedCats = viewModel.categoriesWithTasks
                .filter { $0.category.type == .archived }
                .map { $0.category }
            
            let isArchivedTask: Bool = {
                if let holder = viewModel.categoriesWithTasks.first(
                    where: { $0.tasks.contains(where: { $0.id == task.id }) }
                ) {
                    return holder.category.type == .archived
                }
                return false
            }()
            
            TaskMenuSheet(
                taskTitle: task.title,
                isDueToday: isToday,
                initialDueDate: task.dueDate,
                archivedCategories: archivedCats,
                onArchive: { selected in
                    Task {
                        await viewModel.moveTaskToCategory(taskId: task.id, toCategoryId: selected.id)
                    }
                    activeTask = nil
                },
                
                onDoToday: {
                    Task {
                        await viewModel.updateTaskDate(taskId: task.id, newDate: Date())
                        activeTask = nil
                    }
                },
                onDoTomorrow: {
                    Task {
                        await viewModel.updateTaskDate(taskId: task.id, newDate: tomorrow)
                        activeTask = nil
                    }
                },
                onChangeDate:{ /* do nothing */ },
                onConfirmChangeDate: { picked in
                    Task {
                        await viewModel.updateTaskDate(taskId: task.id, newDate: picked)
                        activeTask = nil
                    }
                },
                onMakeRoutine:{ /* hook later */ },
                onDelete:    {
                    Task {
                        await viewModel.deleteTask(task: task)
                        activeTask = nil
                    }
                },
                onEditTitle: { newTitle in
                    Task {
                        await viewModel.updateTaskTitle(taskId: task.id, newTitle: newTitle)
                    }
                },
                isArchivedTask: isArchivedTask   // NEW
            )
            .presentationDetents([ .height(380) ])
            .presentationCornerRadius(24)
            .presentationDragIndicator(.visible)
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
            .padding(20)
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

            Text(categoryWithTasks.category.name)
                .appFont(AppFont.title3)
                .padding(.leading, 2)

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
        }
    }
    
    private func taskRow(for task: TaskListItem) -> some View {
        HStack(spacing: 12) {
            taskCheckbox(for: task)
            taskContent(for: task)
                .padding(.leading, 1.42)
            Spacer()
            taskMenuButton(for: task)
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
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(Color(.systemGray6))
            TextField("Type...", text: Binding(
                get: { editingTexts[task.id] ?? "" },
                set: { editingTexts[task.id] = $0 }
            ))
            .appFont(AppFont.body1)
            .padding(8)
            .background(Color.clear)
            .textFieldStyle(PlainTextFieldStyle())
            .focused($focusedTaskId, equals: task.id)
            .onAppear {
                editingTexts[task.id] = ""
                focusedTaskId = task.id
            }
            .onSubmit {
                handleTaskSubmit(task: task)
            }
        }
        .frame(height: 36)
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
    
    private func handleTaskSubmit(task: TaskListItem) {
        let text = editingTexts[task.id] ?? ""
        if !text.isEmpty {
            Task {
                await viewModel.saveTemporaryTask(task: task, newTitle: text)
            }
        } else {
            viewModel.removeTemporaryTask(task: task)
        }
        editingTexts.removeValue(forKey: task.id)
        focusedTaskId = nil
    }
}
