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

    var body: some View {
        GeometryReader { geo in
            let collapsed = minHeight
            let expanded  = maxHeight

            Color.clear
                .onAppear {
                    currentHeight = collapsed
                    progress = 0
                }

            VStack(spacing: 0) {
                // Grabber handle
                Capsule()
                    .fill(Color.secondary)
                    .frame(width: 40, height: 5)
                    .padding(.top, 6)

                // Sheet content
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 4)
            }
            .frame(height: currentHeight + dragOffset)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 5)
            )
            .offset(y: geo.size.height - (currentHeight + dragOffset))
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        // value.translation.height 양수 = 아래로, 음수 = 위로
                        let tentative = currentHeight - value.translation.height
                        state = max(collapsed, min(expanded, tentative)) - currentHeight
                    }
                    .onEnded { value in
                        let tentative = currentHeight - value.translation.height
                        let midpoint = (collapsed + expanded) / 2
                        // 중간보다 크게 끌어올렸으면 expanded, 아니면 collapsed
                        let target = tentative > midpoint ? expanded : collapsed
                        currentHeight = target
                        progress = (currentHeight - collapsed) / (expanded - collapsed)
                    }
            )
            .onChange(of: dragOffset) { _ in
                let raw = currentHeight + dragOffset
                progress = (raw - collapsed) / (expanded - collapsed)
            }
            .animation(.interactiveSpring(), value: currentHeight + dragOffset)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
