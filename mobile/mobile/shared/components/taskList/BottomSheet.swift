//
//  BottomSheet.swift
//  mobile
//
//  Created by 이채린 on 7/22/25.
//

import SwiftUI

/// A draggable bottom-sheet that snaps only to collapsed or expanded positions,
/// reporting its open progress (0‥1).
struct BottomSheet<Content: View>: View {

    // MARK: Public
    let minHeight: CGFloat          // collapsed height
    let maxHeight: CGFloat          // fully-expanded height
    @Binding var progress: CGFloat  // 0 (collapsed) → 1 (expanded)

    @ViewBuilder var content: () -> Content

    // MARK: Private
    @State private var currentHeight: CGFloat = .zero
    @GestureState private var dragOffset: CGFloat = 0
    
    private let epsilon: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let collapsed = minHeight
            let expanded  = maxHeight
            
            let liveHeight = currentHeight + dragOffset
            let isExpanded = (expanded - liveHeight) <= epsilon
            
            let outsideTapAreaHeight = max(0, geo.size.height - (currentHeight + dragOffset))

            Color.clear
                .onAppear {
                    currentHeight = collapsed
                    progress = 0
                }
            
            // --- Shared drag gesture (used either on whole sheet OR only on grabber) ---
            let dragGesture = DragGesture()
                .updating($dragOffset) { value, state, _ in
                    // value.translation.height: positive = down, negative = up
                    let tentative = currentHeight - value.translation.height
                    state = max(collapsed, min(expanded, tentative)) - currentHeight
                }
                .onEnded { value in
                    let tentative = currentHeight - value.translation.height
                    let midpoint = (collapsed + expanded) / 2
                    // Decide final snap
                    let target = tentative > midpoint ? expanded : collapsed
                    currentHeight = target
                    progress = (currentHeight - collapsed) / (expanded - collapsed)
                }
            
            ZStack(alignment: .top) {
                Color.clear
                    .frame(height: outsideTapAreaHeight)
                    .contentShape(Rectangle())
                    .allowsHitTesting(currentHeight > collapsed + 0.1)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.10)) {
                            currentHeight = collapsed
                            progress = 0
                        }
                    }

            // sheet
            VStack(spacing: 0) {
                // Grabber handle
//                Capsule()
//                    .fill(.neutral800)
//                    .frame(width: 40, height: 5)
//                    .padding(.vertical, 6)
//                    .zIndex(2)
//                    .gesture(dragGesture)

                // Sheet content
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 4)
            }
            .frame(height: currentHeight + dragOffset)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.neutral1000)
            )
            .offset(y: outsideTapAreaHeight)
            .modifier(HighPriorityDrag(enabled: !isExpanded, gesture: dragGesture))
            .onChange(of: dragOffset) { _ in
                let raw = currentHeight + dragOffset
                progress = (raw - collapsed) / (expanded - collapsed)
            }
            .animation(.interactiveSpring(), value: currentHeight + dragOffset)
            } // ZStack
            .onAppear {
                currentHeight = collapsed
                progress = 0
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
// ViewModifier to conditionally apply highPriorityGesture
private struct HighPriorityDrag<G: Gesture>: ViewModifier {
    let enabled: Bool
    let gesture: G

    func body(content: Content) -> some View {
        if enabled {
            // While collapsed (or during the lift to expand), sheet’s drag wins
            content.highPriorityGesture(gesture)
        } else {
            // Once fully expanded, let inner scroll views handle vertical drags first
            content
        }
    }
}
