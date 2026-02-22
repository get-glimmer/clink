//
//  DropdownSelector.swift
//  mobile
//
//  Created by User on 2/11/26.
//

import SwiftUI

// MARK: - Preference Keys for dropdown positioning
struct DropdownBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

// MARK: - Reusable Dropdown Component
struct DropdownSelector<T: Hashable>: View {
    let options: [T]
    @Binding var selectedOption: T
    let onSelect: (T) -> Void
    let labelForOption: (T) -> String
    let isPresented: Binding<Bool>
    
    // Customization
    var rowHeight: CGFloat = 44
    var width: CGFloat = 178
    var maxVisibleRows: Int = 4
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let dividerThickness: CGFloat = 0.5
            let totalRows = CGFloat(options.count) * rowHeight
            let totalDividers = CGFloat(max(0, options.count - 1)) * dividerThickness
            let contentHeight = totalRows + totalDividers
            
            // Calculate container height based on content, but you might want a max height if list is long
            // For now, using logic similar to CommunityView's fixed height idea or dynamic
            // CommunityView used 152 for ~3 items. Let's make it dynamic or fixed based on content.
            // basic logic: contentHeight + padding?
            
            // Replicating CommunityView exact logic for now:
            let containerHeight: CGFloat = contentHeight // Simplified, or pass in if needed specific
            
             // For exact match to CommunityView logic which had fixed 152 for 3 items:
             // 3 * 44 + 2 * 0.5 = 132 + 1 = 133. 152-133=19 padding.
             // Let's just use VStack and padding.
             
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                Button(action: {
                    selectedOption = option
                    onSelect(option)
                    withAnimation { isPresented.wrappedValue = false }
                }) {
                    HStack(spacing: 0) {
                        Text(labelForOption(option))
                            .foregroundColor(AppColors.textWhite)
                            .appText(AppFont.labelL)
                        Spacer(minLength: 0)
                        if selectedOption == option {
                            Image("checkMark")
                                .renderingMode(.template)
                                .foregroundColor(AppColors.textWhite)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: rowHeight, alignment: .center)
                }
                
                if index < options.count - 1 {
                    Divider()
                        .frame(height: dividerThickness)
                        .background(AppColors.neutral800)
                        .padding(.horizontal, 20)
                }
            }
        }
        .frame(width: width, alignment: .topLeading)
        .padding(.vertical, 8) // Add some vertical padding to container
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
    }
}

// MARK: - Dropdown Overlay Modifier
struct DropdownOverlayModifier<T: Hashable>: ViewModifier {
    @Binding var isPresented: Bool
    let options: [T]
    @Binding var selection: T
    let onSelect: (T) -> Void
    let labelForOption: (T) -> String
    
    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(DropdownBoundsPreferenceKey.self) { anchor in
                GeometryReader { proxy in
                    if isPresented, let a = anchor {
                        let rect = proxy[a]
                        ZStack(alignment: .topLeading) {
                            // Dismiss background
                            Color.black.opacity(0.0001)
                                .ignoresSafeArea()
                                .onTapGesture { isPresented = false }

                            // Dropdown
                            DropdownSelector(
                                options: options,
                                selectedOption: $selection,
                                onSelect: onSelect,
                                labelForOption: labelForOption,
                                isPresented: $isPresented
                            )
                            .offset(x: rect.minX, y: rect.maxY + 8) // Added a little gap
                            .animation(.easeInOut(duration: 0.2), value: isPresented)
                        }
                    }
                }
            }
    }
}

extension View {
    func dropdownOverlay<T: Hashable>(
        isPresented: Binding<Bool>,
        options: [T],
        selection: Binding<T>,
        onSelect: @escaping (T) -> Void,
        labelTitle: @escaping (T) -> String
    ) -> some View {
        modifier(DropdownOverlayModifier(
            isPresented: isPresented,
            options: options,
            selection: selection,
            onSelect: onSelect,
            labelForOption: labelTitle
        ))
    }
}
