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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 16)
                    .frame(width: 370, height: 368)
                    .foregroundColor(.primary.opacity(0.05))
                
                HStack {
                    Text("Daily Task")
                        .font(.headline)
                }
                .padding(.top, 24)
                .padding(.bottom, 4)
                
                ForEach(viewModel.categoriesWithTasks) { categoryWithTasks in
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .foregroundColor(Color(.systemGray6))
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(categoryWithTasks.category.emoji)
                                Text(categoryWithTasks.category.name)
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    viewModel.createTemporaryTask(categoryId: categoryWithTasks.category.id)
                                }) {
                                    Image(systemName: "plus")
                                        .imageScale(.small)
                                        .frame(width: 20, height: 30)
                                        .foregroundColor(.primary)
                                }
                            }
                            ForEach(categoryWithTasks.tasks) { task in
                                HStack(spacing: 12) {
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
                                    
                                    if task.isTemporary {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .foregroundColor(Color(.systemGray6))
                                            TextField("Type...", text: Binding(
                                                get: { editingTexts[task.id] ?? "" },
                                                set: { editingTexts[task.id] = $0 }
                                            ))
                                            .font(.body)
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
                                    } else {
                                        Text(task.title)
                                            .font(.body)
                                            .strikethrough(task.isCompleted, color: .primary)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
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
                                                .imageScale(.small)
                                                .frame(width: 20, height: 30)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                    .frame(maxWidth: .infinity, minHeight: categoryWithTasks.tasks.isEmpty ? 60 : 120)
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal)
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