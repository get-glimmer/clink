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
            
            Text(viewModel.statusMessage)
                .foregroundColor(viewModel.isSupabaseConnected ? .green : .red)
                .font(.headline)

            List(viewModel.tasks) { task in
                VStack(alignment: .leading) {
                    Text(task.title).font(.headline)
                    Text(task.content).font(.subheadline)
                }
            }
        }
        .padding()
    }
}

