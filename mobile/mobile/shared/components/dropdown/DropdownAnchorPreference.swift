//
//  DropdownAnchorPreference.swift
//  mobile
//
//  Created by Kristie Lee on 10/10/25.
//

import SwiftUI

/// 🔗 PreferenceKey to capture an anchor (header area) for dropdown placement.
public struct DropdownAnchorPreferenceKey: PreferenceKey {
    public static var defaultValue: Anchor<CGRect>? = nil
    public static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// 🧭 Attach this to the header that should anchor the dropdown (e.g., .background).
public struct DropdownAnchorCapture: View {
    public init() {}
    public var body: some View {
        GeometryReader { proxy in
            Color.clear
                .anchorPreference(key: DropdownAnchorPreferenceKey.self, value: .bounds) { $0 }
        }
    }
}
