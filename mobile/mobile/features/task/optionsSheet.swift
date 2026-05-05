//
//  OptionsSheet.swift
//  mobile
//
//  Created by 이채린 on 8/20/25.
//

import SwiftUI

/// Popup menu appearing near the options button (matches DropdownSelector style).
struct OptionsSheet: View {
    let onTapOutside: () -> Void
    let onTapRoutines: () -> Void
    let onTapCategories: () -> Void
    let onTapAddCategory: () -> Void
    
    private let rowHeight: CGFloat = 44
    private let menuWidth: CGFloat = 192
    private let menuHeight: CGFloat = 152
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // --- Background: transparent tap area (tap to close) ---
            Color.black.opacity(0.0001)
                .onTapGesture { onTapOutside() }
            
            // --- Popup menu ---
            VStack(alignment: .leading, spacing: 0) {
                OptionRow(iconName: "clock",
                          title: "Routines",
                          action: onTapRoutines)
                
                Divider()
                    .frame(height: 0.5)
                    .background(Color("Neutral-800"))
                    .padding(.horizontal, 20)
                
                OptionRow(iconName: "type",
                          iconSize: 22,
                          title: "Categories",
                          action: onTapCategories)
                
                Divider()
                    .frame(height: 0.5)
                    .background(Color("Neutral-800"))
                    .padding(.horizontal, 20)
                
                OptionRow(systemImage: "plus",
                          title: "Add Category",
                          action: onTapAddCategory)
            }
            .frame(width: menuWidth, height: menuHeight)
            .background(AppColors.neutral900)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color("Neutral-400").opacity(0.7),
                                Color("Neutral-600").opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.top, 70)
            .padding(.trailing, 16)
        }
        .navBarHidden(true)
    }
}

/// One row: icon + title
private struct OptionRow: View {
    var iconName: String? = nil
    var iconSize: CGFloat = 18
    var systemImage: String? = nil
    let title: String
    let action: () -> Void
    
    private let rowHeight: CGFloat = 48

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconName = iconName {
                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(.white)
                        .frame(width: 20)
                } else if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 20)
                }
                
                Text(title)
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.labelL)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(height: rowHeight, alignment: .center)
        }
        .buttonStyle(.plain)
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
