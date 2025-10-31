//
//  View+Dropdown.swift
//  mobile
//
//  Created by Kristie Lee on 10/10/25.
//

import SwiftUI

/// 🧱 Convenience API to present DropdownMenu anchored to a header.
/// 1) Add `.background(DropdownAnchorCapture())` to the header view.
/// 2) Attach `.dropdownMenu(...)` to the parent container that should show the overlay.
public extension View {
    func dropdownMenu<OptionID: Hashable>(
        isPresented: Binding<Bool>,
        options: [DropdownOption<OptionID>],
        selectedID: Binding<OptionID?>,
        style: DropdownStyle = .init(),
        onSelect: @escaping (DropdownOption<OptionID>) -> Void
    ) -> some View {
        self.overlay(
            DropdownMenu(
                isPresented: isPresented,
                options: options,
                selectedID: selectedID,
                style: style,
                onSelect: onSelect
            )
        )
    }
}
