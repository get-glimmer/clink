import SwiftUI
import MCEmojiPicker

// MARK: - DB payload

private struct MemberEmojiUpsert: Encodable {
    let challenge_id: UUID
    let user_id: UUID
    let role: String
    let member_emoji: String
}

// MARK: - ViewModel

@MainActor
class MemberEmojiSetupViewModel: ObservableObject {
    @Published var selectedEmoji: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var didConfirmSuccessfully = false

    private let challengeId: UUID
    private let isOwner: Bool
    private let client = SupabaseClientManager.shared.client

    init(challengeId: UUID, isOwner: Bool) {
        self.challengeId = challengeId
        self.isOwner = isOwner
    }

    func confirmEmoji() async {
        guard !selectedEmoji.isEmpty, let client = client else { return }
        isLoading = true
        errorMessage = nil
        do {
            let session = try await client.auth.session
            let userId = session.user.id

            if isOwner {
                // Owner row already exists — just update the emoji.
                try await client
                    .from("challenge_members")
                    .update(["member_emoji": selectedEmoji])
                    .eq("challenge_id", value: challengeId.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
            } else {
                // Member: upsert into challenge_members then remove the invite row.
                let memberRow = MemberEmojiUpsert(
                    challenge_id: challengeId,
                    user_id: userId,
                    role: "member",
                    member_emoji: selectedEmoji
                )
                try await client
                    .from("challenge_members")
                    .upsert(memberRow)
                    .execute()

                try await client
                    .from("challenge_invites")
                    .delete()
                    .eq("challenge_id", value: challengeId.uuidString)
                    .eq("invitee_user_id", value: userId.uuidString)
                    .execute()
            }

            didConfirmSuccessfully = true
        } catch {
            errorMessage = "Failed to join challenge: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - View

struct MemberEmojiSetupView: View {
    let emojiRule: EmojiRule
    let presetEmojis: [String]        // rule 1 — preset pool from challenge creator
    let representativeEmoji: String   // unused (kept for API compatibility)
    let isOwner: Bool

    @StateObject private var viewModel: MemberEmojiSetupViewModel
    @Environment(\.dismiss) private var dismiss

    // emoji picker state for any_emoji rule
    @State private var showPicker = false
    @State private var pickerEmoji = ""

    init(challengeId: UUID, emojiRule: EmojiRule, presetEmojis: [String], representativeEmoji: String, isOwner: Bool = false) {
        self.emojiRule = emojiRule
        self.presetEmojis = presetEmojis
        self.representativeEmoji = representativeEmoji
        self.isOwner = isOwner
        _viewModel = StateObject(wrappedValue: MemberEmojiSetupViewModel(challengeId: challengeId, isOwner: isOwner))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.neutral1000.ignoresSafeArea()

            // Main content above the bottom panel
            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                switch emojiRule {
                case .selectedOnly:
                    presetGrid
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                case .anyEmoji:
                    anyEmojiBackground
                        .padding(.top, 40)
                }

                Spacer()
            }

            bottomPanel
        }
        .navBarHidden(true)
        .onAppear {
            // Pre-select first emoji for selectedOnly rule
            if emojiRule == .selectedOnly, let first = presetEmojis.first {
                viewModel.selectedEmoji = first
            }
        }
        .onChange(of: pickerEmoji) { emoji in
            guard !emoji.isEmpty else { return }
            viewModel.selectedEmoji = emoji
            pickerEmoji = ""
        }
        .onChange(of: viewModel.didConfirmSuccessfully) { done in
            if done { dismiss() }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image("back_button")
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color("Neutral-900")))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Emoji Setup")
                .appFont(AppFont.title2)
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.top, 8)
    }

    // MARK: - Rule 1: tappable preset emoji grid

    private var presetGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(presetEmojis, id: \.self) { emoji in
                let isSelected = viewModel.selectedEmoji == emoji
                Text(emoji)
                    .font(.system(size: 75))
                    .frame(width: 100, height: 100)
                    .background(
                        Circle()
                            .fill(isSelected ? Color("Neutral-700") : Color.clear)
                    )
                    .onTapGesture {
                        viewModel.selectedEmoji = emoji
                    }
            }
        }
    }

    // MARK: - Rule 2: decorative 🔥 with radial glow

    private var anyEmojiBackground: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.08), Color.clear]),
                center: .center,
                startRadius: 0,
                endRadius: 197
            )
            .frame(width: 394, height: 394)

            Text("🔥")
                .font(.system(size: 120))
        }
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color(red: 0x37/255.0, green: 0x36/255.0, blue: 0x36/255.0))
                .frame(width: 44, height: 3)
                .padding(.top, 9)
                .padding(.bottom, 16)

            Text(emojiRule == .selectedOnly ? "Pick your emoji from above" : "Pick your emoji")
                .appFont(AppFont.title3)
                .foregroundColor(.white)
                .padding(.bottom, 16)

            Rectangle()
                .fill(Color("Neutral-800"))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

            // Preview / picker area
            emojiPreviewArea
                .frame(height: 92)
                .padding(.bottom, 24)

            joinButton
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Color.clear.background(.ultraThinMaterial)
                Color(red: 32/255, green: 32/255, blue: 32/255, opacity: 0.5)
            }
        }
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24
            )
            .strokeBorder(Color(white: 161/255, opacity: 0.7), lineWidth: 1)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24
            )
        )
    }

    @ViewBuilder
    private var emojiPreviewArea: some View {
        switch emojiRule {
        case .selectedOnly:
            Text(viewModel.selectedEmoji)
                .font(.system(size: 92))

        case .anyEmoji:
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 1)
                    .emojiPicker(
                        isPresented: $showPicker,
                        selectedEmoji: $pickerEmoji,
                        arrowDirection: .up,
                        customHeight: 380,
                        horizontalInset: .zero,
                        isDismissAfterChoosing: true,
                        selectedEmojiCategoryTintColor: .white,
                        feedBackGeneratorStyle: .light
                    )

                if viewModel.selectedEmoji.isEmpty {
                    Button {
                        showPicker = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(Color("Neutral-800")))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(viewModel.selectedEmoji)
                        .font(.system(size: 92))
                        .onTapGesture { showPicker = true }
                }
            }
        }
    }

    // MARK: - Join button

    private var joinButton: some View {
        Button {
            Task { await viewModel.confirmEmoji() }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color("Neutral-800"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Join Challenge")
                    .appFont(AppFont.title3)
                    .foregroundColor(viewModel.selectedEmoji.isEmpty ? Color("Neutral-500") : Color("Neutral-1000"))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(viewModel.selectedEmoji.isEmpty ? Color("Neutral-800") : Color("Green-300"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .disabled(viewModel.selectedEmoji.isEmpty || viewModel.isLoading)
    }
}
