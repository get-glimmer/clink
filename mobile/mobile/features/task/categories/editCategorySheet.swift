//
//  editCategorySheet.swift
//  mobile
//
//  Created by 이채린 on 8/20/25.
//

import SwiftUI
import MCEmojiPicker

struct EditCategorySheet: View {
    // Inject the shared view model
    @ObservedObject var viewModel: TaskListViewModel
    
    // Input model (read-only)
    let category: CategoryItem

    // Output callbacks
    var onDone: (_ emoji: String, _ name: String, _ privacy: String, _ type: CategoryType) -> Void
    var onDelete: () -> Void

    // Local UI states
    @Environment(\.dismiss) private var dismiss
    @State private var emoji: String
    @State private var name: String
    @State private var privacy: Privacy
    @State private var isEmojiPickerPresented = false
    @State private var errorMessage: String? = nil
    @State private var isSaving = false
    @State private var catType: CategoryType

    // Initialize local states from category
    init(
        viewModel: TaskListViewModel,
        category: CategoryItem,
        onDone: @escaping (_ emoji: String, _ name: String, _ privacy: String, _ type: CategoryType) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.category = category
        self.onDone = onDone
        self.onDelete = onDelete

        // Use latest emoji from history map; fallback to category.emoji for safety
        let latest = viewModel.latestEmoji(for: category.id, defaultEmoji: category.emoji)
        _emoji = State(initialValue: latest)         // ← changed
        _name  = State(initialValue: category.name)
        let p = Privacy(rawValue: category.privacyStatus ?? "public") ?? .publicShare
        _privacy = State(initialValue: p)
        _catType = State(initialValue: category.type)
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
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { dismiss() }) {
                            Image("dismissButton")
                        }
                        .buttonStyle(.plain)
                    }

                    ToolbarItem(placement: .principal) {
                        Text("Edit Category")
                            .appFont(AppFont.title2)
                            .foregroundColor(Color("White"))
                    }

                    // Delete
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Image("trashcan")
                        }
                    }
                }
            // Vertical gap under header
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 20)
            }
        }
        .padding(.top, 12)
        .onReceive(viewModel.$latestEmojiForCategory) { map in
            if let v = map[category.id], v != emoji {
                emoji = v
            }
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
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
                                .foregroundColor(Color("Neutral-400"))
                                .padding(8)
                                .background(Circle().fill(Color("Neutral-800")))
                        }
                    }
                }
                .frame(width: 96, height: 96)
            }
            .padding(.top, 8)
            
            // --- emoji picker ---
            Rectangle()
                .fill(.clear)
                .frame(height: 1)
                .emojiPicker(
                    isPresented: $isEmojiPickerPresented,
                    selectedEmoji: $emoji,
                    arrowDirection: .up,
                    customHeight: 380,
                    horizontalInset: .zero,
                    isDismissAfterChoosing: true,
                    selectedEmojiCategoryTintColor: .white,
                    feedBackGeneratorStyle: .light
                )

            // Title field
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .appFont(AppFont.labelS)
                    .foregroundColor(Color("Neutral-300"))
                    .padding(.horizontal, 8)

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
                            .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
                    )
            }
            .padding(.horizontal, 16)

            // Options section
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .appFont(AppFont.labelS)
                    .foregroundColor(Color("Neutral-300"))
                    .padding(.horizontal, 8)

                VStack(spacing: 0) {
                    // Row 1: Visibility
                    HStack {
                        HStack(spacing: 10) {
                            Image("visibility")
                            Text("Visibility")
                                .appFont(AppFont.labelM)
                                .foregroundColor(.neutral300)
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
                                Image("chevronUpdown")
                            }
                        }
                        .menuStyle(.automatic)
                    }
                    .frame(height: 52)
                    .padding(.horizontal, 12)

                    // Divider between rows
                    Rectangle()
                        .fill(Color("Neutral-800"))
                        .frame(height: 0.7)
                        .padding(.horizontal, 12)

                    // Row 2: Type
                    HStack {
                        HStack {
                            Image("type")
                            Text("Type")
                                .appFont(AppFont.labelM)
                                .foregroundColor(.neutral300)
                        }
                        Spacer()
                        Menu {
                            Button("Daily")    { catType = .daily }
                            Button("Archived") { catType = .archived }
                        } label: {
                            HStack {
                                Text(catType == .daily ? "Daily" : "Archived")
                                    .appFont(AppFont.body1)
                                    .foregroundColor(Color("White"))
                                Image("chevronUpdown")
                            }
                        }
                    }
                    .frame(height: 52)
                    .padding(.horizontal, 12)
                }
                .background(
                    // Single rounded rectangle for both rows
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.clear)
                        .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
                )
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 16)

            if let err = errorMessage, !err.isEmpty {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .padding(.bottom, 4)
                    .padding(.horizontal, 16)
            }

            // Done button
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
                onDone(emoji, name, privacy.rawValue, catType)
                isSaving = false
                dismiss()
            } label: {
                Text(isSaving ? "Saving..." : "Done")
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .appFont(AppFont.title3)                   // 버튼 텍스트도 규격화
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
