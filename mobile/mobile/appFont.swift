//
//  appFont.swift
//  mobile
//
//  Created by 이채린 on 8/21/25.
//

// HOW TO USE: ex).appFont(AppFont.body1)

import SwiftUI

struct AppFont {

    // MARK: - Family (PostScript names)
    enum Family {
        static let bold   = "Figtree-Bold"
        static let medium = "Figtree-Medium"
        static let regular = "Figtree-Regular"
        static let semibold = "Figtree-Semibold"
    }

    // MARK: - Style token (size / lineHeight / letterSpacing / fontName)
    struct Style: Equatable {
        let fontName: String
        let size: CGFloat
        let lineHeight: CGFloat
        let letterSpacing: CGFloat

        var font: Font { .custom(fontName, size: size) }

        var lineSpacing: CGFloat { max(0, lineHeight - size) }
    }

    // MARK: - Design tokens
    // Headline
    static let headlineL = Style(fontName: Family.bold,   size: 36, lineHeight: 36 * 1.25, letterSpacing: 0)
    static let headlineM = Style(fontName: Family.bold,   size: 32, lineHeight: 32 * 1.25, letterSpacing: 0)
    static let headlineS = Style(fontName: Family.bold,   size: 28, lineHeight: 28 * 1.25, letterSpacing: 0)

    // Title
    static let title1    = Style(fontName: Family.bold,   size: 24, lineHeight: 24 * 1.25, letterSpacing: 0)
    static let title2    = Style(fontName: Family.bold,   size: 20, lineHeight: 20 * 1.25, letterSpacing: 0)
    static let title3    = Style(fontName: Family.bold,   size: 18, lineHeight: 18 * 1.25, letterSpacing: 0)

    // Label
    static let labelL    = Style(fontName: Family.bold,   size: 16, lineHeight: 24,       letterSpacing: 0)
    static let labelM    = Style(fontName: Family.bold,   size: 14, lineHeight: 20,       letterSpacing: 0)
    static let labelS    = Style(fontName: Family.bold,   size: 12, lineHeight: 16,       letterSpacing: 0)

    // Body
    static let body1     = Style(fontName: Family.regular, size: 16, lineHeight: 16 * 1.5, letterSpacing: 0) // 24
    static let body2     = Style(fontName: Family.regular, size: 14, lineHeight: 14 * 1.5, letterSpacing: 0) // 21

    // Caption
    static let captionL  = Style(fontName: Family.regular, size: 16, lineHeight: 24,       letterSpacing: 0)
    static let captionM  = Style(fontName: Family.regular, size: 14, lineHeight: 22,       letterSpacing: 0)
    static let captionS  = Style(fontName: Family.regular, size: 12, lineHeight: 16,       letterSpacing: 0)
    static let captionXS = Style(fontName: Family.regular, size: 11, lineHeight: 16,       letterSpacing: 0)
    static let captionXS_M = Style(fontName: Family.medium, size: 11, lineHeight: 22,      letterSpacing: 0)
    
    // Button
    static let buttonL     = Style(fontName: Family.semibold, size: 16, lineHeight: 24, letterSpacing: 0) // 24
    static let buttonM     = Style(fontName: Family.semibold, size: 12, lineHeight: 16, letterSpacing: 0) // 21
}

// MARK: - View modifier & sugar
private struct AppTextModifier: ViewModifier {
    let style: AppFont.Style

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .kerning(style.letterSpacing)            // letter spacing
            .lineSpacing(style.lineSpacing)          // simulate line-height
            .fixedSize(horizontal: false, vertical: true)
            // .foregroundStyle(...) // optional: global text color
    }
}

extension View {
    func appText(_ style: AppFont.Style) -> some View {
        modifier(AppTextModifier(style: style))
    }
}
