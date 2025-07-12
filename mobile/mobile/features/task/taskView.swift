//
//  homeView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI

struct TaskView: View {
    @State private var userId = getUserId()
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
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RoundedRectangle(cornerRadius: 16)
                        .frame(width: 370, height: 368)
                        .foregroundColor(.primary.opacity(0.05))
                    
                    Text("Daily Task")
                        .font(.headline)

                    ForEach(viewModel.categoriesWithTasks) { categoryWithTasks in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(categoryWithTasks.category.emoji)
                                Text(categoryWithTasks.category.name)
                                    .font(.headline)
                            }
                            ForEach(categoryWithTasks.tasks) { task in
                                HStack {
                                    Button(action: {
                                        viewModel.toggleTaskCompletion(task: task)
                                    }) {
                                        Image(systemName: task.isCompleted ? "checkmark.square" : "square")
                                            .foregroundColor(task.isCompleted ? .green : .primary)
                                            .imageScale(.large)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    VStack(alignment: .leading) {
                                        Text(task.title)
                                            .font(.headline)
                                        Text(task.content)
                                            .font(.subheadline)
                                    }
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
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
}

