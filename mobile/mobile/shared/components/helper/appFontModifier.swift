//
//  appFontModifier.swift
//  mobile
//
//  Created by 이채린 on 8/21/25.
//

// HOW TO USE: ex).appFont(AppFont.body1)

import SwiftUI

private struct AppFontModifier: ViewModifier {
    let style: AppFont.Style

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .kerning(style.letterSpacing)
            .lineSpacing(style.lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    func appFont(_ style: AppFont.Style) -> some View {
        self.modifier(AppFontModifier(style: style))
    }
}
