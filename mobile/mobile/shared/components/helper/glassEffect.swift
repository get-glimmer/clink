//
//  glassEffect.swift
//  mobile
//
//  Created by 이채린 on 8/21/25.
//

import SwiftUI

/// Liquid-glass style background with material blur, tint, highlights, inner/outer strokes, and subtle noise.
struct LiquidGlass: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let tintOpacity: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 1) Base material (glass blur)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // 2) Color tint overlay
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(tintOpacity))
                    
                    // 3) Soft directional highlight
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.28),
                                    .white.opacity(0.10),
                                    .clear,
                                    .black.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                        .opacity(0.8)
                    
                    // 4) Inner stroke for glass edge definition
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.65),
                                    .white.opacity(0.15),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .blendMode(.overlay)
                    
                    // 5) Subtle noise to avoid flat plastic look
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.black.opacity(0.001)) // hit-testing mask
                        .overlay(
                            Canvas { ctx, size in
                                // Tiny random grain dots
                                let dots = 450
                                for _ in 0..<dots {
                                    let x = CGFloat.random(in: 0...size.width)
                                    let y = CGFloat.random(in: 0...size.height)
                                    let r = CGFloat.random(in: 0.3...0.9)
                                    let opacity = Double.random(in: 0.02...0.05)
                                    ctx.fill(
                                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                                        with: .color(.black.opacity(opacity))
                                    )
                                }
                            }
                            .allowsHitTesting(false)
                            .blendMode(.overlay)
                            .opacity(0.35)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        )
                }
            )
            // 6) Outer soft shadow to lift the glass from background
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
    }
}

extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 50,
        tint: Color = .clear,
        tintOpacity: Double = 0.5
    ) -> some View {
        self.modifier(LiquidGlass(cornerRadius: cornerRadius, tint: tint, tintOpacity: tintOpacity))
    }
}
