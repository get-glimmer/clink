//
//  BottomSheet.swift
//  mobile
//
//  Revised: limit gesture hit area to the sheet only,
//  allow configurable hit heights, and add yOffset to align under shaker.
//

import SwiftUI

/// A draggable bottom-sheet that snaps only to collapsed or expanded positions,
/// reporting its open progress (0‥1). When expanded, a downward pull from the
/// top of the inner ScrollView (within a hot area) collapses the sheet.
struct BottomSheet<Content: View>: View {

    // MARK: - Public
    let minHeight: CGFloat                 // collapsed height
    let maxHeight: CGFloat                 // expanded height
    @Binding var progress: CGFloat         // 0 (collapsed) → 1 (expanded)

    /// Vertical offset applied to the entire sheet. Negative value pulls the sheet upward.
    let yOffset: CGFloat

    /// While not expanded: height (from the top of the sheet) that accepts expand-drag.
    /// Use .infinity to allow dragging from anywhere inside the sheet area.
    let expandHitAreaHeight: CGFloat

    /// While expanded: height (from the top of the sheet) that accepts pull-down-to-collapse.
    let pullDownHitAreaHeight: CGFloat

    @ViewBuilder var content: () -> Content

    // MARK: - Private
    @State private var currentHeight: CGFloat = .zero
    @GestureState private var dragOffset: CGFloat = 0
    @State private var innerScrollAtTop: Bool = true

    private var isExpanded: Bool {
        abs(currentHeight - maxHeight) < 0.5
    }

    // MARK: - Init convenience
    init(
        minHeight: CGFloat,
        maxHeight: CGFloat,
        progress: Binding<CGFloat>,
        yOffset: CGFloat = 0,
        expandHitAreaHeight: CGFloat = .infinity,
        pullDownHitAreaHeight: CGFloat = 96,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self._progress = progress
        self.yOffset = yOffset
        self.expandHitAreaHeight = expandHitAreaHeight
        self.pullDownHitAreaHeight = pullDownHitAreaHeight
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let collapsed = minHeight
            let expanded  = maxHeight

            ZStack(alignment: .bottom) {
                // --- Sheet ---
                VStack(spacing: 0) {

                    // Content area
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        // Listen to inner ScrollView offset (via preference)
                        .onPreferenceChange(ScrollTopPreferenceKey.self) { y in
                            // y >= 0 means the scroll content is at (or beyond) its top
                            innerScrollAtTop = (y >= 0)
                        }
                }
                .frame(height: currentHeight + dragOffset)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 6, y: -2)
                )
                .contentShape(Rectangle())
                .zIndex(1)
                // Place the sheet at the bottom, then shift by yOffset to hug the shaker above.
                .offset(y: geo.size.height - (currentHeight + dragOffset) + yOffset)
                .animation(.interactiveSpring(), value: currentHeight + dragOffset)
                .onChange(of: dragOffset) { _ in
                    let live = currentHeight + dragOffset
                    progress = (live - collapsed) / (expanded - collapsed)
                }
                .onAppear {
                    currentHeight = collapsed
                    progress = 0
                }

                // --- Gesture hit areas (confined to sheet bounds) ---

                // 1) When NOT expanded: a hit band (within the sheet) to expand/collapse.
                if !isExpanded {
                    VStack { Spacer() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(height: currentHeight + dragOffset) // match sheet height
                        .overlay(alignment: .top) {
                            // Hit only inside the sheet, height-limited
                            Color.clear
                                .frame(height: expandHitAreaHeight)
                                .contentShape(Rectangle())
                                .highPriorityGesture(expandCollapseGesture(collapsed: collapsed, expanded: expanded))
                        }
                        .allowsHitTesting(true)
                        // Align the hit container exactly over the sheet
                        .offset(y: geo.size.height - (currentHeight + dragOffset) + yOffset)
                        .zIndex(2)
                }

                // 2) When expanded AND inner scroll is at top: a top hit band to pull down.
                if isExpanded && innerScrollAtTop {
                    VStack { Spacer() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(height: currentHeight + dragOffset)
                        .overlay(alignment: .top) {
                            Color.clear
                                .frame(height: pullDownHitAreaHeight)
                                .contentShape(Rectangle())
                                .highPriorityGesture(pullDownToCollapseGesture(collapsed: collapsed, expanded: expanded))
                        }
                        .allowsHitTesting(true)
                        .offset(y: geo.size.height - (currentHeight + dragOffset) + yOffset)
                        .zIndex(2)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Gestures

    /// General drag between collapsed/expanded; snaps at midpoint.
    private func expandCollapseGesture(collapsed: CGFloat, expanded: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                // value.translation.height: +down, -up
                let tentative = currentHeight - value.translation.height
                let clamped = max(collapsed, min(expanded, tentative))
                state = clamped - currentHeight
            }
            .onEnded { value in
                let tentative = currentHeight - value.translation.height
                let midpoint = (collapsed + expanded) / 2
                let target = tentative > midpoint ? expanded : collapsed
                currentHeight = target
                progress = (currentHeight - collapsed) / (expanded - collapsed)
            }
    }

    /// When expanded and inner scroll is at top, allow downward pull to collapse.
    private func pullDownToCollapseGesture(collapsed: CGFloat, expanded: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                // Only react to downward pulls (translation.height > 0)
                guard value.translation.height > 0 else { return }
                let tentative = currentHeight - value.translation.height
                let clamped = max(collapsed, min(expanded, tentative))
                state = clamped - currentHeight
            }
            .onEnded { value in
                // If pulled down sufficiently, snap to collapsed; else return to expanded.
                let tentative = currentHeight - max(0, value.translation.height)
                let midpoint = (collapsed + expanded) / 2
                let target = tentative > midpoint ? expanded : collapsed
                currentHeight = target
                progress = (currentHeight - collapsed) / (expanded - collapsed)
            }
    }
}

// MARK: - Scroll offset plumbing

/// Emits the vertical position (minY) of a marker inside a ScrollView with the
/// coordinateSpace named "BottomSheetScroll". Place `BottomSheetScrollDetector()`
/// at the top of the ScrollView content.
private struct ScrollTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct BottomSheetScrollDetector: View {
    var body: some View {
        GeometryReader { proxy in
            // minY in the named scroll space: 0 at top, negative when scrolled down
            let y = proxy.frame(in: .named("BottomSheetScroll")).minY
            Color.clear.preference(key: ScrollTopPreferenceKey.self, value: y)
        }
        .frame(height: 0) // occupy no space
    }
}
