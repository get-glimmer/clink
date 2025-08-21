import SwiftUI
import MCEmojiPicker

struct AddCategorySheet: View {
    // Bindings from parent
    @Binding var emoji: String
    @Binding var name: String
    @Binding var isSaving: Bool
    @Binding var errorMessage: String?

    // Save callback: (emoji, name, privacy)
    var onSave: (_ emoji: String, _ name: String, _ privacy: String) -> Void

    // Local UI states
    @Environment(\.dismiss) private var dismiss
    @State private var privacy: Privacy = .publicShare
    @State private var isEmojiPickerPresented: Bool = false
    @State private var isValidEmoji: Bool = true

    // Keep same Privacy enum & display text as Edit sheet
    enum Privacy: String, CaseIterable, Identifiable {
        case userOnly = "user_only"
        case friendsOnly  = "friends_only"
        case publicShare = "public"
        var id: String { rawValue }
        var display: String {
            switch self {
            case .userOnly:    return "Private"
            case .friendsOnly: return "Friends"
            case .publicShare: return "Public"
            }
        }
    }

    var body: some View {
        NavigationStack {
            content
                // Emoji picker - appear lower like a small bottom sheet
                .emojiPicker(isPresented: $isEmojiPickerPresented,
                             selectedEmoji: $emoji)
                .presentationDetents([.height(260)])
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { dismiss() }) {
                            ZStack {
                                Circle()
                                    .fill(Color("Netural-800").opacity(0.3))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color("Netural-400"))
                            }
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    ToolbarItem(placement: .principal) {
                        Text("Add Category")
                            .appFont(AppFont.title2)
                            .foregroundColor(Color("White"))
                    }
                }
                // small vertical gap under header
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 20)
                }
        }
    }

    private var content: some View {
        VStack(spacing: 24) {

            // --- Emoji avatar with pencil trigger ---
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
                            Image("pencilFilled")
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

            // --- Title field ---
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .appFont(AppFont.labelS)
                    .foregroundColor(Color("Netural-300"))

                TextField("Write a title...", text: $name)
                    .appFont(AppFont.body1)
                    .foregroundColor(Color("White"))
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.clear)
                            .strokeBorder(Color("Netural-600"), lineWidth: 0.7)
                    )
            }
            .padding(.horizontal, 16)

            // --- Options ---
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .appFont(AppFont.labelS)
                    .foregroundColor(Color("Netural-300"))

                VStack(spacing: 0) {

                    // Row 1: Visibility
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("White"))
                            Text("Visibility")
                                .appFont(AppFont.body1)
                                .foregroundColor(Color("White"))
                        }

                        Spacer()

                        Menu {
                            ForEach(Privacy.allCases) { p in
                                Button(p.display) { privacy = p }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(privacy.display)
                                    .appFont(AppFont.body1)
                                    .foregroundColor(Color("White"))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.footnote)
                                    .foregroundColor(Color("White"))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                        .menuStyle(.automatic)
                    }
                    .frame(height: 52)
                    .padding(.horizontal, 12)

                    // Inner divider
                    Rectangle()
                        .fill(Color("Netural-800"))
                        .frame(height: 0.7)
                        .padding(.horizontal, 12)

                    // Row 2: Type
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.grid.1x2")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("White"))
                            Text("Type")
                                .appFont(AppFont.body1)
                                .foregroundColor(Color("White"))
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Text("Daily")
                                .appFont(AppFont.body1)
                                .foregroundColor(Color("White"))
                            Image(systemName: "lock.fill")
                                .font(.footnote)
                                .foregroundColor(Color("Netural-400"))
                        }
                    }
                    .frame(height: 52)
                    .padding(.horizontal, 12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.clear)
                        .strokeBorder(Color("Netural-600"), lineWidth: 0.7)
                )
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 16)

            // Error message
            if let err = errorMessage, !err.isEmpty {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .padding(.bottom, 4)
                    .padding(.horizontal, 16)
            }

            // --- Done button ---
            Button {
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
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .appFont(AppFont.title3)
                    .background(isSaving ? Color("Green-300").opacity(0.5) : Color("Green-300"))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isSaving)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Emoji validation (same as original)
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
