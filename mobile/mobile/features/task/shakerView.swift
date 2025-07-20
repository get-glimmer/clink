//
//  shakerView.swift
//  mobile
//
//  Created by 이채린 on 6/29/25.
//

import SwiftUI
import SpriteKit

struct ShakerView: View {
    
    // single scene instance
    private let jarSize = CGSize(width: 270, height: 270)
    @State private var scene   = ShakerScene(size: CGSize(width: 270, height: 270))
    @State private var shakerOn = false          // shaker mode flag
    @State private var lidColors  = [Color.black, Color.gray]   // lid colors (gradient)
    @State private var lidOpacity = 0.0
    @State private var isSealed:  Bool   = false   // sealed flag
    
    private let emojiMap = [1: "🍟", 2: "🌈", 3: "🌷"]
    
    var body: some View {
        VStack {
            ZStack {
                // --- Jar ---
                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width,
                           height: jarSize.height)
                    .allowsHitTesting(false)
                
                // ─── Lid ───
                Rectangle()
                    .fill(
                        LinearGradient(colors: lidColors,
                                       startPoint: .leading,
                                       endPoint:   .trailing)
                    )
                    .frame(width: jarSize.width,
                           height: 46 )
                    .cornerRadius(13)
                    .offset(y: -jarSize.height/2 + 23.5)
                    .opacity(lidOpacity)
                    .animation(.easeInOut(duration: 0.25),
                               value: lidOpacity) // slowly disappears
                
                // --- Physics canvas ---
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
                Button("Reset") {
                    scene.resetScene()
                    lidOpacity = 0
                    isSealed   = false
                }
                    .font(.title3)
                    .frame(width: 80, height: 50)
                    .background(Color.blue.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Shaker Toggle
                Toggle("Shaker", isOn: $shakerOn)
                    .font(.title3)
                    .frame(width: 120)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .onChange(of: shakerOn) { _ in
                        scene.toggleShaker()
                    }
                // Seal
                Button("Seal") {
                    applySealGradient()
                }
                .font(.title3)
                .frame(width: 80, height: 50)
                .background(Color.blue.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
    // MARK: - Helper
    /// Call ShakerScene → dominantColors() and update lid gradient
    private func applySealGradient() {
        // 1. 상위 3색 가져오기
        let ui = scene.dominantColors()

        // 2. 두 번째·세 번째 dominant 색 사용
        let grad: [Color] = {
            if ui.count >= 3 {                 // 정상 케이스
                return [Color(ui[1]), Color(ui[2])]
            } else if ui.count == 2 {          // 색이 2개뿐이면 2색 그대로
                return ui.map { Color($0) }
            } else if ui.count == 1 {          // 1개뿐이면 톤 차이
                let base = Color(ui[0])
                return [base, base.opacity(0.8)]
            } else {                           // fallback
                return [.black, .gray]
            }
        }()

        withAnimation(.easeInOut(duration: 0.3)) {
            lidColors = grad
            lidOpacity = 1
            isSealed  = true
        }
    }
}


#Preview { ShakerView() }

