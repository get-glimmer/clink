//
//  editCategorySheet.swift
//  mobile
//
//  Created by 이채린 on 8/20/25.
//
import SwiftUI

struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var category: CategoryModel
    var onSave: (CategoryModel) -> Void

    var body: some View {
        AddCategorySheet(
            emoji: $category.emoji,
            name: $category.name,
            isSaving: .constant(false),
            errorMessage: .constant(nil),
            onSave: { emoji, name, privacy in
                var updated = category
                updated.emoji = emoji
                updated.name = name
                updated.privacyStatus = privacy
                onSave(updated)
                dismiss()
            }
        )
        .navigationTitle("Edit Category")
        .navigationBarTitleDisplayMode(.inline)
    }
}
