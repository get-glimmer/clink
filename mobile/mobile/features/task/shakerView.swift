//
//  shakerView.swift
//  mobile
//
//  Created by 이채린 on 7/21/25.
//

import SwiftUI
import SpriteKit
import UIKit

struct ShakerView: View {
    // External state
    @ObservedObject var viewModel: TaskListViewModel
    
    // SpriteKit scene
    @State private var scene = ShakerScene(size: .zero)
    
    // Completion cache - add/remove marbles
    @State private var completionCache: [UUID: Bool] = [:]
    
    // Lid visuals
    @State private var lidColors: [Color] = [.black, .gray]
    @State private var lidOpacity: Double = 0
    // Lid position & size
    private let lidHeightRatio:      CGFloat = 46.0 / 270.0
    private let lidCornerRatio:      CGFloat = 13.0 / 270.0
    private let lidTopInsetRatio:    CGFloat = 23.5 / 270.0
    
    
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let jarSize = CGSize(width: side, height: side)
            
            ZStack {
                // --- Jar ---
                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)
                
                // --- Lid(Gradient) ---
                Rectangle()
                    .fill(
                        LinearGradient(colors: lidColors,
                                       startPoint: .leading,
                                       endPoint:   .trailing)
                    )
                    .frame(
                        width: jarSize.width,
                        height: jarSize.height * lidHeightRatio
                    )
                    .cornerRadius(jarSize.height * lidCornerRatio)
                    .offset(
                        y: -jarSize.height / 2                // jar top
                        + jarSize.height * lidTopInsetRatio
                    )
                    .opacity(lidOpacity)
                    .animation(.easeInOut(duration: 0.25), value: lidOpacity)
                    .allowsHitTesting(false)
                
                // --- Physics(canvas) ---
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .frame(width: jarSize.width, height: jarSize.height)
            }
            .onAppear {
                scene = ShakerScene(size: jarSize)
                syncWithTasks()
                updateSeal(animated: false)
            }
        }
        .onReceive(viewModel.$categoriesWithTasks) { _ in syncWithTasks() }
        .onReceive(viewModel.$isAllCompleted)      { _ in updateSeal(animated: true) }
    }
    
    // MARK: - Marble Syncing
    private func syncWithTasks() {
        var current: [UUID: (Bool, String)] = [:]
        for cat in viewModel.categoriesWithTasks {
            for task in cat.tasks {
                current[task.id] = (task.isCompleted, cat.category.emoji)
            }
        }
        // add marble
        for (id, info) in current where info.0 && completionCache[id] != true {
            scene.addEmoji(info.1, for: id)
        }
        // remove marble
        for (id, wasCompleted) in completionCache where wasCompleted {
            if current[id]?.0 != true {
                scene.removeEmoji(for: id)
            }
        }
        completionCache = current.mapValues { $0.0 }
    }
    
    // MARK: - Seal / Unseal
    private func updateSeal(animated: Bool) {
        if viewModel.isAllCompleted {
            lidColors = gradientFromScene()
            withAnimation(animated ? .easeInOut(duration: 0.3) : nil) {
                lidOpacity = 1
            }
        } else {
            withAnimation(animated ? .easeInOut(duration: 0.25) : nil) {
                lidOpacity = 0
            }
        }
    }
    
    private func gradientFromScene() -> [Color] {
        
        //        let ui = scene.marbleDominantColors(maxCount: 2)
        //
        //        if ui.count == 2 { return ui.map { Color($0) } }
        //        if ui.count == 1 {
        //            let c = Color(ui[0]); return [c, c.opacity(0.7)]
        //        }
        //        return [.black, .gray]
        
        //1) grab up to 3 dominant colors
        let ui = scene.marbleDominantColors(maxCount: 3)
        // 2) Normal case: use #1 and #3
        if ui.count >= 3 {
            return [Color(ui[0]), Color(ui[2])]
        }
        
        // 3) Fallbacks
        if ui.count == 2 {          // two colors → use both
            return ui.map { Color($0) }
        }
        if ui.count == 1 {          // one → duplicate with opacity
            let c = Color(ui[0]); return [c, c.opacity(0.7)]
        }
        return [.black, .gray]      // none found
        
        //        //1) grab up to 3 dominant colors
        //        let ui = scene.dominantColors(maxCount: 3)
        //        // 2) Normal case: use #2 and #3
        //        if ui.count >= 3 {
        //            return [Color(ui[1]), Color(ui[2])]
        //        }
        //
        //        // 3) Fallbacks
        //        if ui.count == 2 {          // two colors → use both
        //            return ui.map { Color($0) }
        //        }
        //        if ui.count == 1 {          // one → duplicate with opacity
        //            let c = Color(ui[0]); return [c, c.opacity(0.7)]
        //        }
        //        return [.black, .gray]      // none found
    }
}
