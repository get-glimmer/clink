//
//  OptionsSheet.swift
//  mobile
//
//  Created by 이채린 on 8/20/25.
//

import SwiftUI

/// Fullscreen dim + floating options stack at bottom-left.
struct OptionsSheet: View {
    let onTapOutside: () -> Void
    let onTapRoutines: () -> Void
    let onTapCategories: () -> Void
    let onTapAddCategory: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // --- Background: blur + dim (tap to close) ---
            ZStack {
                DarkBlurView(style: .systemChromeMaterialDark)
                    .ignoresSafeArea()

                Color.black.opacity(0.7)
                    .ignoresSafeArea()
            }
            .contentShape(Rectangle())
            .onTapGesture { onTapOutside() }
            
            // --- Floating options ---
            VStack(alignment: .leading, spacing: 30) {
                OptionRow(systemImage: "clock.arrow.circlepath",
                          title: "Routines",
                          isEnabled: true,
                          action: onTapRoutines)
                
                OptionRow(systemImage: "rectangle.grid.1x2",
                          title: "Categories",
                          isEnabled: true,
                          action: onTapCategories)
                
                OptionRow(systemImage: "plus",
                          title: "Add Category",
                          isEnabled: true,
                          action: onTapAddCategory)
            }
            .padding(.bottom, 78)
            .padding(.leading, 31)
        }
        .navBarHidden(true)
    }
}

/// One row: green circular icon + title
private struct OptionRow: View {
    let systemImage: String
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color("Green-300"))
                    .frame(width: 44, height: 44)

                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
            }

            Text(title)
                .appFont(AppFont.title3)
                .foregroundStyle(.white)
                .opacity(isEnabled ? 1.0 : 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEnabled else { return }
            action()
        }
        .allowsHitTesting(isEnabled)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OptionsSheet(
            onTapOutside: {},
            onTapRoutines: {},
            onTapCategories: {},
            onTapAddCategory: {}
        )
    }
    .preferredColorScheme(.dark)
}
