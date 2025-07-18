//
//  shakerView.swift
//  mobile
//
//  Created by 이채린 on 6/29/25.
//

import SwiftUI
import SpriteKit

struct shakerView: View {
    
    // single scene instance
    private let jarSize = CGSize(width: 270, height: 270)
    @State private var shakerOn = false          // Toggle state
    private let emojiMap = [1: "🤎", 2: "🍦", 3: "🧸"]

    @StateObject private var scene = shakerScene(size: CGSize(width: 270, height: 270))
    var emojiToDrop: String?

    var body: some View {
        HStack {
            Spacer()
            ZStack {
                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 270, height: 270)
                    .allowsHitTesting(false)
                SpriteView(scene: scene,
                            options: [.allowsTransparency])
                    .frame(width: 270, height: 270)
                    .onChange(of: emojiToDrop) { newEmoji in
                        if let emoji = newEmoji {
                            scene.dropEmoji(emoji)
                        }
                    }
            }
            Spacer()
        }
    }
}
