//
//  addCategorySheet.swift
//  mobile
//
//  Created by 이채린 on 8/12/25.
//

import SwiftUI

struct AddCategorySheet: View {
    @Binding var emoji: String
    @Binding var name: String
    @Binding var isSaving: Bool
    @Binding var errorMessage: String?

    /// Called when user taps "Save" after passing lightweight validation.
    var onSave: (_ emoji: String, _ name: String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Emoji")) {
                    TextField("e.g. 🍀", text: $emoji)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.default)
                        .onChange(of: emoji) { _, newVal in
                            // Keep it reasonably short; don't hard‑fail for composed emojis.
                            if newVal.count > 8 { emoji = String(newVal.prefix(8)) }
                        }
                }

                Section(header: Text("Category Name")) {
                    TextField("e.g. Personal", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }

                if let err = errorMessage, !err.isEmpty {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Add Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        onSave(emoji, name)
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

#Preview {
    AddCategorySheet(
        emoji: .constant("🍀"),
        name: .constant("Personal"),
        isSaving: .constant(false),
        errorMessage: .constant(nil),
        onSave: {_,_ in}
    )
}
