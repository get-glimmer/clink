//
//  ScrollOffsetReader.swift
//  mobile
//
//  Created by Kristie Lee on 10/7/25.
//

import SwiftUI

// ⭐️ Track vertical scroll offset from a named coordinate space
private struct ScrollOffsetKey: PreferenceKey {              // ⭐️
    static var defaultValue: CGFloat = 0                     // ⭐️
    static func reduce(value: inout CGFloat,                 // ⭐️
                       nextValue: () -> CGFloat) {           // ⭐️
        value = nextValue()
    }
}

// ⭐️ Measure the height of the pinned (Header + Shaker) area
private struct ViewHeightKey: PreferenceKey {                // ⭐️
    static var defaultValue: CGFloat = 0                     // ⭐️
    static func reduce(value: inout CGFloat,
                       nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
