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
    
    // store current emoji per completed task
    @State private var emojiCache: [UUID: String] = [:]
    
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
                if scene.size == .zero { // create a new scene only once
                        scene = ShakerScene(size: jarSize)
                    }
                scene.setMotionEnabled(true)
                completionCache.removeAll()
                syncWithTasks()
                updateSeal(animated: false)
            }
            .onDisappear {
                scene.setMotionEnabled(false) // for performance
            }
        }
        .onReceive(viewModel.$categoriesWithTasks) { _ in syncWithTasks() }
        .onChange(of: viewModel.emojiForDate) { _ in syncWithTasks()
            // isAllCompleted 였다면 이모지 변경에 따라 기존 뚜껑색 변경 유도.
            viewModel.lidColorStart = nil
            viewModel.lidColorEnd = nil
        }
        .onReceive(viewModel.$isAllCompleted)      { _ in syncWithTasks()
            updateSeal(animated: true)
        }
        .onChange(of: viewModel.taskSelectedDate) { newDate in
            syncWithTasks()
            UnsealLidAndUpdate()
        }
    }
    
    // MARK: - Marble Syncing
    private func syncWithTasks() {
        // If scene was cleared (ex. size changed), clear caches as well
        if completionCache.isEmpty == false && scene.children.isEmpty {
            completionCache.removeAll()
            emojiCache.removeAll() // NEW
        }

        // Build current state: (completed?, emoji-for-selected-date)
        var current: [UUID: (Bool, String)] = [:]
        for cat in viewModel.categoriesWithTasks {
            for task in cat.tasks {
                let emj = viewModel.emojiFor(
                    categoryId: cat.category.id,
                    defaultEmoji: cat.category.emoji
                )
                current[task.id] = (task.isCompleted, emj)
            }
        }

        // 1) Update emoji of marbles that remain completed, if the emoji changed
        for (id, info) in current where info.0 && completionCache[id] == true {
            let oldEmoji = emojiCache[id]
            if oldEmoji != info.1 {
                scene.updateEmoji(info.1, for: id)
                emojiCache[id] = info.1
            }
        }

        // 2) Add newly completed marbles
        for (id, info) in current where info.0 && completionCache[id] != true {
            scene.addEmoji(info.1, for: id)
            emojiCache[id] = info.1
        }

        // 3) Remove marbles that are no longer completed
        for (id, wasCompleted) in completionCache where wasCompleted && current[id]?.0 != true {
            scene.removeEmoji(for: id)
            emojiCache.removeValue(forKey: id)
        }

        // 4) Refresh caches
        completionCache = current.mapValues { $0.0 }

        // Prune emojiCache to only keep currently completed tasks
        let valid = Set(current.keys.filter { current[$0]?.0 == true })
        emojiCache = emojiCache.filter { valid.contains($0.key) }
    }

    
    // MARK: - Seal / Unseal
    private func updateSeal(animated: Bool) {
        if viewModel.isAllCompleted {
            // DB에 저장된 색상이 있다면 우선 사용
            if let c0 = Color(hex: viewModel.lidColorStart),
               let c1 = Color(hex: viewModel.lidColorEnd) {
                lidColors = [c0, c1]
            } else {
                // 첫 seal → 마블에서 추출 후 DB 저장
                lidColors = gradientFromScene()
                Task {
                    let h0 = UIColor(lidColors[0]).toHex()
                    let h1 = UIColor(lidColors[1]).toHex()
                    await viewModel.updateShakerLidColors(start: h0, end: h1)
                }
            }
            withAnimation(animated ? .easeInOut(duration: 0.3) : nil) {
                lidOpacity = 1
            }
        } else {
            viewModel.lidColorStart = nil
            viewModel.lidColorEnd   = nil
            
            withAnimation(animated ? .easeInOut(duration: 0.25) : nil) {
                lidOpacity = 0
            }
        }
    }
    private func gradientFromScene() -> [Color] {
        // Grab up to 6 candidate colors
        let ui = scene.marbleDominantColors(maxCount: 6)
        guard let first = ui.first else { return [.black, .gray] }

        // Threshold: gives hue difference
        let threshold: CGFloat = 0.18

        // Find the first colour perceptually far enough from `first`
        if let distinct = ui.dropFirst().first(where: {
            $0.perceptualDistance(to: first) >= threshold
        }) {
            return [Color(first), Color(distinct)]
        }

        // Fallbacks: not enough variety
        if ui.count >= 2 { return ui.prefix(2).map { Color($0) } }
        if ui.count == 1  { let c = Color(first); return [c, c.opacity(0.7)] }
        return [.black, .gray]
    }
    
    private func UnsealLidAndUpdate() {
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            viewModel.isAllCompleted = false
        }
        updateSeal(animated: false)
    }
}
// MARK: - Color helpers
private extension UIColor {
    // Returns HSBA components in 0‥1 range
    var hsba: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }

    // Quick perceptual distance (Hue + Saturation)
    func perceptualDistance(to other: UIColor) -> CGFloat {
        let lhs = self.hsba
        let rhs = other.hsba
        // Hue wrap-around handled via min(|Δh|, 1-|Δh|)
        let dh = abs(lhs.h - rhs.h)
        let hueDist = min(dh, 1 - dh)
        let satDist = abs(lhs.s - rhs.s)
        return hueDist * 0.7 + satDist * 0.3     // weighted
    }
}
