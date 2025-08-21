//
//  editCategorySheet.swift
//  mobile
//
//  Created by 이채린 on 8/20/25.
//

import SwiftUI
import MCEmojiPicker

struct EditCategorySheet: View {
    // Input model (read-only)
    let category: CategoryItem

    // Output callbacks
    var onDone: (_ emoji: String, _ name: String, _ privacy: String) -> Void
    var onDelete: () -> Void

    // Local UI states
    @Environment(\.dismiss) private var dismiss
    @State private var emoji: String
    @State private var name: String
    @State private var privacy: Privacy
    @State private var isEmojiPickerPresented = false
    @State private var errorMessage: String? = nil
    @State private var isSaving = false

    // Initialize local states from category
    init(category: CategoryItem,
         onDone: @escaping (_ emoji: String, _ name: String, _ privacy: String) -> Void,
         onDelete: @escaping () -> Void)
    {
        self.category = category
        self.onDone = onDone
        self.onDelete = onDelete

        // default states
        _emoji = State(initialValue: category.emoji)
        _name  = State(initialValue: category.name)
        let p = Privacy(rawValue: category.privacyStatus ?? "public") ?? .publicShare
        _privacy = State(initialValue: p)
    }

    enum Privacy: String, CaseIterable, Identifiable {
        case userOnly = "user_only"
        case friendsOnly  = "friends_only"
        case publicShare = "public"
        var id: String { rawValue }
        var display: String {
            switch self {
            case .userOnly: return "Private"
            case .friendsOnly: return "Friends"
            case .publicShare: return "Public"
            }
        }
    }

    var body: some View {
        NavigationStack {
            content
                .emojiPicker(
                    isPresented: $isEmojiPickerPresented,
                    selectedEmoji: $emoji
                )
                .navigationTitle("Edit Category")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Back
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Image(systemName: "chevron.backward") }
                    }
                    // Delete
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            // Emoji avatar + pencil
            ZStack {
                Circle().fill(Color.clear).frame(width: 96, height: 96)

                Text(emoji.isEmpty ? "🔥" : emoji)
                    .font(.system(size: 96))
                    .frame(width: 96, height: 96)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { isEmojiPickerPresented = true } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color("Netural-400"))
                                .padding(8)
                                .background(Circle().fill(Color("Netural-800")))
                        }
                    }
                }
                .frame(width: 96, height: 96)
            }
            .padding(.top, 8)

            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Exercise", text: $name)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial.opacity(0.2))
                    )
            }
            .padding(.horizontal, 16)

            // Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Visibility
                HStack {
                    Label("Visibility", systemImage: "globe")
                    Spacer()
                    Menu {
                        ForEach(Privacy.allCases) { p in
                            Button(p.display) { privacy = p }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(privacy.display)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.4)))
                    }
                }
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial.opacity(0.2)))

                // Type (fixed)
                HStack {
                    Label("Type", systemImage: "doc.plaintext")
                    Spacer()
                    Text("Daily")
                        .foregroundStyle(.secondary)
                    Image(systemName: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial.opacity(0.2)))
            }
            .padding(.horizontal, 16)

            Spacer()

            if let err = errorMessage, !err.isEmpty {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .padding(.bottom, 4)
                    .padding(.horizontal, 16)
            }

            Button {
                // Basic validations
                guard AddCategorySheet.isPureEmoji(emoji) else {
                    errorMessage = "Please select a valid emoji."
                    return
                }
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    errorMessage = "Please enter a category name."
                    return
                }
                isSaving = true
                onDone(emoji, name, privacy.rawValue)
                isSaving = false
                dismiss()
            } label: {
                Text(isSaving ? "Saving..." : "Done")
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .font(.headline)
                    .background(isSaving ? Color("Green-300").opacity(0.5) : Color("Green-300"))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isSaving)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
