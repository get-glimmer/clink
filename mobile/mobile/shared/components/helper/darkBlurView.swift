//
//  Untitled.swift
//  mobile
//
//  Created by Kristie Lee on 10/8/25.
//

import SwiftUI

/// Wraps UIVisualEffectView so we can use dark blur styles in SwiftUI.
struct DarkBlurView: UIViewRepresentable {
    /// Good choices: .systemChromeMaterialDark (가장 어둡게),
    ///               .systemThickMaterialDark, .systemMaterialDark
    var style: UIBlurEffect.Style = .systemChromeMaterialDark

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
