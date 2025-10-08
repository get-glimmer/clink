//
//  Untitled.swift
//  mobile
//
//  Created by Kristie Lee on 10/8/25.
//

//
//  ShakerTaskScrollView.swift
//  mobile
//
//  Purpose: A single-scroll layout that morphs between a large Shaker header and
//  a task list. As you scroll up, the Shaker shrinks until minHeight, then only
//  the task list scrolls. When fully expanded and scrolled to top, pulling down
//  stretches the Shaker back (elastic).
//
//  Usage:
//  ShakerTaskScrollView(
//      shakerMaxHeight: 380,
//      shakerMinHeight: 140,
//      collapseDistance: 240
//  ) {
//      // Shaker content view (scaled automatically)
//  } taskList: {
//      // Task list content (ScrollView children)
//  }
//

import SwiftUI

public struct ShakerTaskScrollView<Shaker: View, Tasks: View>: View {

    // MARK: Config
    let shakerMaxHeight: CGFloat      // header max height (when fully expanded)
    let shakerMinHeight: CGFloat      // header min height (when collapsed)
    let collapseDistance: CGFloat     // scroll distance to go from max → min
    let showsIndicators: Bool

    // MARK: Slots
    @ViewBuilder let shaker: () -> Shaker
    @ViewBuilder let taskList: () -> Tasks

    // MARK: State
    @State private var scrollY: CGFloat = 0  // current scroll offset (0 at top, +down)
    @State private var isAtTop: Bool = true  // whether the scroll is at top (>= 0)
    
    public init(
        shakerMaxHeight: CGFloat,
        shakerMinHeight: CGFloat,
        collapseDistance: CGFloat,
        showsIndicators: Bool = true,
        @ViewBuilder shaker: @escaping () -> Shaker,
        @ViewBuilder taskList: @escaping () -> Tasks
    ) {
        self.shakerMaxHeight = shakerMaxHeight
        self.shakerMinHeight = shakerMinHeight
        self.collapseDistance = max(1, collapseDistance)
        self.showsIndicators = showsIndicators
        self.shaker = shaker
        self.taskList = taskList
    }

    public var body: some View {
        GeometryReader { proxy in
            let progress = clamp(scrollY / collapseDistance, 0, 1) // 0:expanded → 1:collapsed
            let headerHeight = lerp(from: shakerMaxHeight, to: shakerMinHeight, t: progress)

            // The entire experience is ONE ScrollView to avoid gesture conflicts.
            ScrollView(showsIndicators: showsIndicators) {
                // Offset detector (must be the first)
                OffsetReader()

                // Shaker header (height shrinks with scroll; stretches when pulling down)
                VStack {
                    shaker()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(1.0) // actual visual scaling handled inside shaker view if needed
                        // Tip: If your shaker wants internal scaling, use progress to scale colors/emoji.
                }
                .frame(height: headerHeight + stretchAmount)
                .frame(maxWidth: .infinity)
                .animation(.interactiveSpring(), value: scrollY)

                // Task list content below
                taskList()
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)
            }
            .coordinateSpace(name: "ShakerTaskScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { y in
                // y = content minY in our named space:
                //  0 at top, negative when scrolled down; positive when pulling (elastic) above top.
                scrollY = -y
                isAtTop = (y >= 0)
            }
        }
    }

    // When pulling down at top (elastic), allow header to stretch a bit.
    private var stretchAmount: CGFloat {
        // pulling down => scrollY is negative (since y > 0) → in our mapping, it becomes negative
        // We can add extra height when the raw offset indicates overscroll upward.
        // Here we derive using isAtTop and actual overshoot distance from scrollY sign.
        // Simpler: allow +40px stretch if user pulls down at the top.
        // Implement a soft stretch using a small factor.
        // Note: Because our scrollY is based on -minY, positive overscroll appears as negative scrollY.
        // We'll detect top via isAtTop and re-measure using ScrollOvershootKey if you want finer control.
        return isAtTop ? max(0, 40 - min(40, scrollY)) : 0
    }
}

// MARK: Offset Reader infra

/// Attach at the top of the ScrollView content to emit the vertical offset.
private struct OffsetReader: View {
    var body: some View {
        GeometryReader { gp in
            let minY = gp.frame(in: .named("ShakerTaskScroll")).minY
            Color.clear
                .preference(key: ScrollOffsetKey.self, value: minY)
        }
        .frame(height: 0)
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: Math helpers

@inline(__always)
private func clamp<T: Comparable>(_ x: T, _ a: T, _ b: T) -> T { max(a, min(b, x)) }

@inline(__always)
private func lerp(from a: CGFloat, to b: CGFloat, t: CGFloat) -> CGFloat {
    a + (b - a) * clamp(t, 0, 1)
}
