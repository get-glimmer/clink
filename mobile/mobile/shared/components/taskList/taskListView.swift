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
    
    // used so that fetchCategoriesAndTasks() can fetch data at wanted date
    @Binding var taskSelectedDate: Date
  
    // now accepts a binded date as a parameter
    init(taskSelectedDate: Binding<Date>, viewModel: TaskListViewModel) {
        self._taskSelectedDate = taskSelectedDate
        self.viewModel = viewModel
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                dailyTaskHeader
                categoriesSection
            }
            //.padding(.horizontal)
        }
    }
    
    private var dailyTaskHeader: some View {
        HStack {
            Text("Daily Task")
                .font(.headline)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 4)
    }
    
    private var categoriesSection: some View {
        ForEach(viewModel.categoriesWithTasks) { categoryWithTasks in
            categoryCard(for: categoryWithTasks)
        }
        .padding(.horizontal)
    }
    
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
            Text(categoryWithTasks.category.emoji)
                .appFont(AppFont.title1)
            Text(categoryWithTasks.category.name)
                .appFont(AppFont.title3)
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
        }
    }
    
    private func taskRow(for task: TaskListItem) -> some View {
        HStack(spacing: 12) {
            taskCheckbox(for: task)
            taskContent(for: task)
            Spacer()
            taskMenu(for: task)
        }
    }
    
    private func taskCheckbox(for task: TaskListItem) -> some View {
        Button(action: {
            if !task.isTemporary {
                viewModel.toggleTaskCompletion(task: task)
            }
        }) {
            Image(systemName: task.isCompleted ? "checkmark.circle" : "circle")
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
    private func taskMenu(for task: TaskListItem) -> some View {
        if !task.isTemporary {
            Menu {
                Button("Delete") {
                    Task {
                        await viewModel.deleteTask(task: task)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.primary)
                    .imageScale(.medium)
                    .frame(width: 25, height: 25)
            }
            .contentShape(Rectangle())
        }
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
