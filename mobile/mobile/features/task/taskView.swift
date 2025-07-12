//
//  homeView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI

struct TaskView: View {
    @StateObject private var viewModel: TaskViewModel
    
    init() {
        let userId = getUserId()
        _viewModel = StateObject(wrappedValue: TaskViewModel(userId: userId))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Hi \(getUserName() ?? "User") 👋")
                    .font(.headline)
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.fetchCategoriesAndTasks()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.primary)
                            .imageScale(.small)
                            .frame(width: 20, height: 30)
                    }
                    .padding(.trailing)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
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
                                        Task {
                                            await viewModel.createTask(categoryId: categoryWithTasks.category.id)
                                        }
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
                                            viewModel.toggleTaskCompletion(task: task)
                                        }) {
                                            Image(systemName: task.isCompleted ? "checkmark.circle" : "circle")
                                                .foregroundColor(.primary)
                                                .imageScale(.large)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        Text(task.title)
                                            .font(.body)
                                            .strikethrough(task.isCompleted, color: .primary)
                                            .foregroundColor(.primary)
                                        Spacer()
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
                            .padding(20)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
}

