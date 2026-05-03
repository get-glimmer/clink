import SwiftUI

// MARK: - DB payload

private struct MemberEmojiUpsert: Encodable {
    let challenge_id: UUID
    let user_id: UUID
    let role: String
    let member_emoji: String
}

private struct MemberEmojiRow: Decodable {
    let user_id: UUID
    let member_emoji: String?
    let left_at: String?
}

// MARK: - Hidden emoji keyboard trigger

private struct HiddenEmojiTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool

    private final class EmojiFirstTextField: UITextField {
        override var textInputContextIdentifier: String? { "" }
        override var textInputMode: UITextInputMode? {
            UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
                ?? super.textInputMode
        }
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = EmojiFirstTextField(frame: .zero)
        tf.delegate = context.coordinator
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.tintColor = .clear
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if isFirstResponder && !uiView.isFirstResponder {
            _ = uiView.becomeFirstResponder()
            DispatchQueue.main.async { uiView.reloadInputViews() }
        } else if !isFirstResponder && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: HiddenEmojiTextField
        init(_ parent: HiddenEmojiTextField) { self.parent = parent }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard !string.isEmpty else { return true }
            parent.text = string
            return false
        }
    }
}

// MARK: - ViewModel

@MainActor
class MemberEmojiSetupViewModel: ObservableObject {
    @Published var selectedEmoji: String = ""
    @Published var usedEmojis: Set<String> = []
    @Published var emojiConflictError: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var didConfirmSuccessfully = false

    private let challengeId: UUID?
    private let isOwner: Bool
    private let client = SupabaseClientManager.shared.client

    init(challengeId: UUID?, isOwner: Bool) {
        self.challengeId = challengeId
        self.isOwner = isOwner
    }

    func load(presetEmojis: [String] = [], emojiRule: EmojiRule = .selectedOnly) async {
        guard let challengeId, let client else {
            // Pre-creation: auto-select the first preset emoji for selectedOnly
            if emojiRule == .selectedOnly, let first = presetEmojis.first {
                selectedEmoji = first
            }
            return
        }
        do {
            let session = try await client.auth.session
            let userId = session.user.id
            let rows: [MemberEmojiRow] = try await client
                .from("challenge_members")
                .select("user_id, member_emoji, left_at")
                .eq("challenge_id", value: challengeId.uuidString)
                .execute()
                .value
            usedEmojis = Set(
                rows
                    .filter { $0.left_at == nil && $0.user_id != userId }
                    .compactMap { $0.member_emoji?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
            if emojiRule == .selectedOnly, selectedEmoji.isEmpty,
               let first = presetEmojis.first(where: { !usedEmojis.contains($0) }) {
                selectedEmoji = first
            }
        } catch {}
    }

    func confirmEmoji() async {
        let picked = selectedEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !picked.isEmpty, !isLoading else { return }
        if usedEmojis.contains(picked) {
            emojiConflictError = true
            return
        }

        // Pre-creation owner: no DB writes yet — challenge created after emoji is confirmed
        if isOwner && challengeId == nil {
            didConfirmSuccessfully = true
            return
        }

        guard let challengeId, let client else {
            errorMessage = "Client unavailable"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let session = try await client.auth.session
            let userId = session.user.id

            if isOwner {
                try await client
                    .from("challenge_members")
                    .update(["member_emoji": picked])
                    .eq("challenge_id", value: challengeId.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
            } else {
                let memberRow = MemberEmojiUpsert(
                    challenge_id: challengeId,
                    user_id: userId,
                    role: "member",
                    member_emoji: picked
                )
                try await client.from("challenge_members").upsert(memberRow).execute()
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
    let presetEmojis: [String]
    let representativeEmoji: String
    let isOwner: Bool
    var onConfirmed: ((String) -> Void)?

    @StateObject private var viewModel: MemberEmojiSetupViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var pickedEmoji: String = ""
    @State private var isEmojiKeyboardFocused: Bool = false

    @State private var randomEmoji: String = "🎉"
    private let randomEmojiPool: [String] = [
        "😀","😂","🥰","😎","🤩","🎉","🔥","💪","🌟","⚡️",
        "🎯","🏆","💫","🌈","🦋","🍀","💎","🚀","🎸","🎨",
        "🌺","🦊","🐬","🦁","🐼","🍕","🎃","👑","🌙","💥",
        "🎵","🌊","🦄","🐉","🍓","🎭","🌸","🏄","🎪","🦸"
    ]

    init(
        challengeId: UUID?,
        emojiRule: EmojiRule,
        presetEmojis: [String],
        representativeEmoji: String,
        isOwner: Bool = false,
        onConfirmed: ((String) -> Void)? = nil
    ) {
        self.emojiRule = emojiRule
        self.presetEmojis = presetEmojis
        self.representativeEmoji = representativeEmoji
        self.isOwner = isOwner
        self.onConfirmed = onConfirmed
        _viewModel = StateObject(wrappedValue: MemberEmojiSetupViewModel(challengeId: challengeId, isOwner: isOwner))
    }

    var body: some View {
        GeometryReader { screen in
            ZStack(alignment: .bottom) {
                AppColors.neutral1000.ignoresSafeArea()

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
                .frame(width: screen.size.width, height: screen.size.height)

                bottomPanel

                // Pinned to the top so UIKit doesn't scroll when this becomes first responder
                VStack {
                    HiddenEmojiTextField(text: $pickedEmoji, isFirstResponder: $isEmojiKeyboardFocused)
                        .frame(width: 1, height: 1)
                        .opacity(0.02)
                        .allowsHitTesting(false)
                    Spacer()
                }
            }
            .ignoresSafeArea(.keyboard)
        }
        .ignoresSafeArea(.keyboard)
        .navBarHidden(true)
        .onAppear {
            Task { await viewModel.load(presetEmojis: presetEmojis, emojiRule: emojiRule) }
        }
        .onChange(of: pickedEmoji) { value in
            guard !value.isEmpty else { return }
            viewModel.selectedEmoji = value
            viewModel.emojiConflictError = false
            pickedEmoji = ""
            isEmojiKeyboardFocused = false
        }
        .onChange(of: viewModel.selectedEmoji) { _ in
            viewModel.emojiConflictError = false
        }
        .onChange(of: viewModel.didConfirmSuccessfully) { done in
            if done {
                onConfirmed?(viewModel.selectedEmoji)
                dismiss()
            }
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
                let isUsed = viewModel.usedEmojis.contains(emoji)
                Text(emoji)
                    .font(.system(size: 75))
                    .frame(width: 100, height: 100)
                    .opacity(isUsed ? 0.35 : 1)
                    .overlay {
                        if isUsed {
                            Image("diagonalWhiteLine")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                        }
                    }
                    .onTapGesture {
                        guard !isUsed else { return }
                        viewModel.selectedEmoji = emoji
                    }
            }
        }
    }

    // MARK: - Rule 2: random cycling emoji with radial glow

    private var anyEmojiBackground: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.08), Color.clear]),
                center: .center,
                startRadius: 0,
                endRadius: 197
            )
            .frame(width: 394, height: 394)

            Text(viewModel.selectedEmoji.isEmpty ? randomEmoji : viewModel.selectedEmoji)
                .font(.system(size: 120))
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if viewModel.selectedEmoji.isEmpty {
                    randomEmoji = randomEmojiPool.randomElement() ?? "🎉"
                }
            }
        }
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 0) {
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

            emojiPreviewArea
                .frame(height: 92)
                .padding(.bottom, 24)

            if viewModel.emojiConflictError {
                Text("This emoji is already taken by another member.")
                    .appFont(AppFont.captionS)
                    .foregroundColor(Color("Red-300"))
                    .padding(.bottom, 8)
            }

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
                topLeadingRadius: 24, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 24
            )
            .strokeBorder(Color(white: 161/255, opacity: 0.7), lineWidth: 1)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 24
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
            if viewModel.selectedEmoji.isEmpty {
                Button {
                    isEmojiKeyboardFocused = true
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
                    .onTapGesture { isEmojiKeyboardFocused = true }
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
                Text(isOwner ? "Confirm Emoji" : "Join Challenge")
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
