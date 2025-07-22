//
//  shakerView.swift
//  mobile
//
//  Created by 이채린 on 7/21/25.
//

import SwiftUI
import SpriteKit

struct ShakerView: View {
    @ObservedObject var viewModel: TaskListViewModel

    // Size will be controlled by parent via .frame
    @State private var scene = ShakerScene(size: CGSize(width: 300, height: 300))

    // Local cache of task completion status to detect changes
    @State private var completionCache: [UUID: Bool] = [:]

    var body: some View {
        ZStack {
            Image("jar")
                .resizable()
                .scaledToFit()
                .allowsHitTesting(false)

            SpriteView(scene: scene, options: [.allowsTransparency])
                .allowsHitTesting(false)
        }
        .onAppear { syncWithTasks() }
        .onReceive(viewModel.$categoriesWithTasks) { _ in syncWithTasks() }
    }

    // MARK: - Sync logic
    private func syncWithTasks() {
        // Flatten all tasks across categories
        var currentStatus: [UUID: (Bool, String)] = [:]   // id -> (isCompleted, emoji)
        for cat in viewModel.categoriesWithTasks {
            for task in cat.tasks {
                currentStatus[task.id] = (task.isCompleted, cat.category.emoji)
            }
        }

        // Add new completed tasks
        for (id, info) in currentStatus where info.0 == true && completionCache[id] != true {
            scene.addEmoji(info.1, for: id)
        }

        // Remove tasks that became incomplete or were deleted
        for (id, wasCompleted) in completionCache where wasCompleted == true {
            if let cur = currentStatus[id]?.0, cur == false || currentStatus[id] == nil {
                scene.removeEmoji(for: id)
            } else if currentStatus[id] == nil {
                scene.removeEmoji(for: id)
            }
        }

        completionCache = currentStatus.mapValues { $0.0 }
    }
}
