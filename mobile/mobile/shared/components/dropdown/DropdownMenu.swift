//
//  DropdownMenu.swift
//  mobile
//
//  Created by Kristie Lee on 10/10/25.
//

import SwiftUI

/// 🎨 Reusable style for the dropdown menu.
public struct DropdownStyle {
    public var width: CGFloat = 178
    public var height: CGFloat = 152
    public var rowHeight: CGFloat = 44
    public var dividerThickness: CGFloat = 0.5
    public var cornerRadius: CGFloat = 16
    public var horizontalPadding: CGFloat = 20

    // Colors (replace with your design system if needed)
    public var containerColor: Color = Color("Neutral-900") // AppColors.neutral900
    public var strokeStart: Color = Color("Neutral-400").opacity(0.7)
    public var strokeEnd: Color = Color("Neutral-600").opacity(0.7)
    public var dividerColor: Color = Color("Neutral-800")   // AppColors.neutral800
    public var textColor: Color = Color.white               // AppColors.textWhite
    public var checkmarkTint: Color = Color.white           // AppColors.textWhite
    public var shadowColor: Color = Color.black.opacity(0.3)

    public init() {}
}

/// ✅ Generic option type helper (you can also pass plain `String`).
public struct DropdownOption<ID: Hashable>: Hashable {
    public let id: ID
    public let label: String
    public init(id: ID, label: String) {
        self.id = id
        self.label = label
    }
}

/// 🧩 Core dropdown menu overlay. It reads the anchor and places the menu aligned left, 16pt below.
public struct DropdownMenu<OptionID: Hashable>: View {
    // Inputs
    @Binding var isPresented: Bool
    public let options: [DropdownOption<OptionID>]
    @Binding public var selectedID: OptionID?
    public var onSelect: (DropdownOption<OptionID>) -> Void

    // Label resolver if you need custom mapping (defaults to .label)
    public var labelProvider: (DropdownOption<OptionID>) -> String = { $0.label }

    // Styling
    public var style: DropdownStyle = .init()

    // Init
    public init(
        isPresented: Binding<Bool>,
        options: [DropdownOption<OptionID>],
        selectedID: Binding<OptionID?>,
        style: DropdownStyle = .init(),
        onSelect: @escaping (DropdownOption<OptionID>) -> Void
    ) {
        self._isPresented = isPresented
        self.options = options
        self._selectedID = selectedID
        self.style = style
        self.onSelect = onSelect
    }

    public var body: some View {
        // The overlay reads the header anchor here.
        overlayPreferenceValue(DropdownAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if isPresented, let a = anchor {
                    let rect = proxy[a]
                    ZStack(alignment: .topLeading) {
                        // Invisible backdrop to dismiss on tap.
                        Color.black.opacity(0.0001)
                            .ignoresSafeArea()
                            .onTapGesture { isPresented = false }

                        // Content container: fixed size by style.
                        VStack(alignment: .leading, spacing: 0) {
                            // --- Vertical centering logic (kept same as your design) ---
                            let totalRows = CGFloat(options.count) * style.rowHeight
                            let totalDividers = CGFloat(max(0, options.count - 1)) * style.dividerThickness
                            let contentHeight = totalRows + totalDividers
                            let verticalPad = max(0, (style.height - contentHeight) / 2)

                            Spacer(minLength: verticalPad)

                            ForEach(options, id: \.self) { option in
                                Button {
                                    selectedID = option.id
                                    isPresented = false
                                    onSelect(option)
                                } label: {
                                    HStack(spacing: 0) {
                                        Text(labelProvider(option))
                                            // NOTE: Replace with your typography helper if needed.
                                            // .appText(AppFont.labelL)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(style.textColor)

                                        Spacer(minLength: 0)

                                        if option.id == selectedID {
                                            Image("checkMark") // template image in your asset
                                                .renderingMode(.template)
                                                .foregroundColor(style.checkmarkTint)
                                        }
                                    }
                                    .padding(.horizontal, style.horizontalPadding)
                                    .frame(height: style.rowHeight, alignment: .center)
                                }
                                .buttonStyle(.plain)

                                if option != options.last {
                                    Divider()
                                        .frame(height: style.dividerThickness)
                                        .background(style.dividerColor)
                                        .padding(.horizontal, style.horizontalPadding)
                                }
                            }

                            Spacer(minLength: verticalPad)
                        }
                        .frame(width: style.width, height: style.height, alignment: .topLeading)
                        .background(style.containerColor)
                        .cornerRadius(style.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: style.cornerRadius)
                                .stroke(
                                    LinearGradient(
                                        colors: [style.strokeStart, style.strokeEnd],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: style.shadowColor, radius: 10, x: 0, y: 5)
                        // 🧷 Position: left-aligned, 16pt below header bottom.
                        .offset(x: rect.minX, y: rect.maxY + 16)
                        .animation(.easeInOut(duration: 0.2), value: isPresented)
                    }
                }
            }
        }
    }
}
