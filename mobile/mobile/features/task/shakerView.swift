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
    @State private var scene   = shakerScene(size: CGSize(width: 270, height: 270))
    @State private var shakerOn = false          // Toggle state
    private let emojiMap = [1: "🤎", 2: "🍦", 3: "🧸"]
    
    var body: some View {
        VStack {
            ZStack {
                // Jar PNG with transparent center
                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width,
                           height: jarSize.height)
                    //.opacity(0.7)
                    .allowsHitTesting(false)
                
                // Physics canvas
                SpriteView(scene: scene,
                           options: [.allowsTransparency])
                    .frame(width: jarSize.width,
                           height: jarSize.height)
            }
            
            Spacer().frame(height: 50)
            
            // Control buttons
            /* ── 1st row ── */
            HStack(spacing: 24) {
                ForEach([1, 2, 3], id: \.self) { num in
                    Button("\(num)") {
                        if let emoji = emojiMap[num] { scene.dropEmoji(emoji) }
                    }
                    .font(.title)
                    .frame(width: 56, height: 56)
                    .background(Color.gray.opacity(0.18))
                    .clipShape(Circle())
                }
            }
            
            Spacer().frame(height: 24)
            
            /* ── 2nd row ── */
            HStack(spacing: 32) {
                // Reset
                Button("Reset") { scene.resetScene() }
                    .font(.title3)
                    .frame(width: 80, height: 50)
                    .background(Color.blue.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Shaker Toggle
                Toggle("Shaker", isOn: $shakerOn)
                    .font(.title3)
                    .frame(width: 140)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .onChange(of: shakerOn) { _ in
                        scene.toggleShaker()
                    }
            }
        }
        .padding()
    }
}


#Preview { shakerView() }

