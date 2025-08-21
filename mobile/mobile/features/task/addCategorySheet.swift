import SwiftUI
import MCEmojiPicker  

struct AddCategorySheet: View {
    // Bindings passed from TaskView
    @Binding var emoji: String
    @Binding var name: String
    @Binding var isSaving: Bool
    @Binding var errorMessage: String?

    // Save callback: (emoji, name, privacy)
    var onSave: (_ emoji: String, _ name: String, _ privacy: String) -> Void

    // Local UI states
    @Environment(\.dismiss) private var dismiss
    @State private var privacy: Privacy = .publicShare
    @State private var isEmojiPickerPresented: Bool = false   // ← MCEmojiPicker trigger
    @State private var isValidEmoji: Bool = true

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
            // -------- MCEmojiPicker SwiftUI modifier -------
            content
                .emojiPicker(
                    isPresented: $isEmojiPickerPresented,
                    selectedEmoji: $emoji
                )
                // Optional configs (uncomment to customize)
/*
                .mcEmojiPicker(
                    isPresented: $isEmojiPickerPresented,
                    selectedEmoji: $emoji,
                    arrowDirection: .up,
                    customHeight: 380.0,
                    horizontalInset: .zero,
                    isDismissAfterChoosing: true,
                    selectedEmojiCategoryTintColor: .systemBlue,
                    feedBackGeneratorStyle: .light
                )
*/
                .navigationTitle("Add Category")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                    }
                }
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            // Emoji avatar + pencil
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 96, height: 96)

                Text(emoji.isEmpty ? "🔥" : emoji)
                    .font(.system(size: 96))
                    .frame(width: 96, height: 96)

                // Pencil button to open MCEmojiPicker
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            isEmojiPickerPresented = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color( "Netural-400"))
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color( "Netural-800"))
                                )
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

            // Options (Visibility & Type)
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Visibility -> privacy_status
                HStack {
                    Label("Visibility", systemImage: "globe")
                        .labelStyle(.titleAndIcon)

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
                        .background(
                            RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.4))
                        )
                    }
                }
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial.opacity(0.2))
                )

                // Type (fixed)
                HStack {
                    Label("Type", systemImage: "doc.plaintext")
                        .labelStyle(.titleAndIcon)

                    Spacer()
                    Text("Daily")
                        .foregroundStyle(.secondary)
                    Image(systemName: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial.opacity(0.2))
                )
            }
            .padding(.horizontal, 16)

            Spacer()

            // Error
            if let err = errorMessage, !err.isEmpty {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .padding(.bottom, 4)
                    .padding(.horizontal, 16)
            }

            // Done
            Button {
                // Validate: emoji-only + non-empty name
                isValidEmoji = Self.isPureEmoji(emoji)
                guard isValidEmoji else {
                    errorMessage = "Please select a valid emoji."
                    return
                }
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    errorMessage = "Please enter a category name."
                    return
                }
                onSave(emoji, name, privacy.rawValue)
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

// MARK: - Emoji validation (heuristic)
extension AddCategorySheet {
    /// Heuristic: disallow obvious alphanumerics; require at least one emoji scalar.
    static func isPureEmoji(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.range(of: #"^[A-Za-z0-9]+$"#, options: .regularExpression) != nil {
            return false
        }
        var hasEmoji = false
        for scalar in trimmed.unicodeScalars {
            if scalar.properties.isEmoji { hasEmoji = true }
            if CharacterSet.alphanumerics.contains(scalar) { return false }
        }
        return hasEmoji
    }
}

#Preview {
    AddCategorySheet(
        emoji: .constant("🔥"),
        name: .constant("Exercise"),
        isSaving: .constant(false),
        errorMessage: .constant(nil),
        onSave: {_,_,_ in}
    )
}
