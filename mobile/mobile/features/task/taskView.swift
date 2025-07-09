//
//  homeView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI

struct TaskView: View {
    @StateObject private var viewModel = TaskViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Tasks")
                .font(.title)

            List(viewModel.tasks) { task in
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
                            .imageScale(.large)
                            .frame(width: 30, height: 44)
                    }
                    .contentShape(Rectangle())
                }
            }

        }
        .padding()
    }
}

