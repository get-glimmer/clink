import SwiftUI

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

struct EmojiSetupView: View {
    @ObservedObject var viewModel: CreateChallengeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pickerEmoji: String = ""
    @State private var isEmojiKeyboardFocused: Bool = false
    @State private var showOwnerEmojiSetup = false

    @State private var randomEmoji: String = "🎉"
    private let randomEmojiPool: [String] = [
        "😀","😂","🥰","😎","🤩","🎉","🔥","💪","🌟","⚡️",
        "🎯","🏆","💫","🌈","🦋","🍀","💎","🚀","🎸","🎨",
        "🌺","🦊","🐬","🦁","🐼","🍕","🎃","👑","🌙","💥",
        "🎵","🌊","🦄","🐉","🍓","🎭","🌸","🏄","🎪","🦸"
    ]
    private let randomEmojiTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { screen in
            ZStack {
                AppColors.neutral1000.ignoresSafeArea()

                // Background tap layer — dismisses keyboard when tapping empty space
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { isEmojiKeyboardFocused = false }

                // Pinned to the top so UIKit doesn't scroll the view when this becomes first responder
                VStack {
                    HiddenEmojiTextField(text: $pickerEmoji, isFirstResponder: $isEmojiKeyboardFocused)
                        .frame(width: 1, height: 1)
                        .opacity(0.02)
                        .allowsHitTesting(false)
                    Spacer()
                }

                VStack(spacing: 0) {
                    headerBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    Spacer()

                    emojiArea
                        .padding(.horizontal, 24)
                        .animation(.none, value: viewModel.selectedEmojis)
                        .transaction { $0.animation = nil }

                    Spacer()

                    VStack(spacing: 0) {
                        rulesSection
                            .padding(.horizontal, 16)

                        // Fixed-height block: Spacer pushes text to the bottom
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            if viewModel.emojiRule == .selectedOnly {
                                Text("Select at least \(viewModel.minEmojiCount) emoji\(viewModel.minEmojiCount == 1 ? "" : "s") for this challenge")
                                    .appFont(AppFont.captionM)
                                    .foregroundColor(Color("Neutral-100"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 14)
                            }
                        }
                        .frame(height: 89)

                        createButton
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
                .frame(width: screen.size.width, height: screen.size.height)
            }
            .ignoresSafeArea(.keyboard)
        }
        .ignoresSafeArea(.keyboard)
        .navBarHidden(true)
        .onChange(of: pickerEmoji) { emoji in
            guard !emoji.isEmpty, viewModel.emojiRule == .selectedOnly else { return }
            if viewModel.selectedEmojis.count < 10 && !viewModel.selectedEmojis.contains(emoji) {
                viewModel.selectedEmojis.append(emoji)
            }
            pickerEmoji = ""
        }
        .fullScreenCover(isPresented: $showOwnerEmojiSetup) {
            MemberEmojiSetupView(
                challengeId: nil,
                emojiRule: viewModel.emojiRule,
                presetEmojis: viewModel.selectedEmojis,
                representativeEmoji: "",
                isOwner: true,
                onConfirmed: { emoji in
                    viewModel.ownerEmoji = emoji
                    Task { await viewModel.createChallenge() }
                }
            )
        }
        .onChange(of: viewModel.didCreateSuccessfully) { didCreate in
            if didCreate { dismiss() }
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

    // MARK: - Emoji display area

    @ViewBuilder
    private var emojiArea: some View {
        switch viewModel.emojiRule {
        case .selectedOnly:
            selectedEmojisArea
        case .anyEmoji:
            singleEmojiArea
        }
    }

    // Rule 1: count-based emoji layout + inline add button
    @ViewBuilder
    private var selectedEmojisArea: some View {
        if viewModel.selectedEmojis.isEmpty {
            Button {
                isEmojiKeyboardFocused = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 120)
                    .background(Circle().fill(Color("Neutral-800")))
            }
            .buttonStyle(.plain)
        } else {
            let layout = selectedEmojiLayout

            VStack(spacing: layout.rowSpacing) {
                ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: layout.itemSpacing) {
                        ForEach(row, id: \.self) { item in
                            switch item {
                            case .emoji(let index):
                                emojiCell(at: index, size: layout.itemSize)
                            case .add:
                                addEmojiCell(size: layout.itemSize)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func emojiCell(at i: Int, size: CGSize) -> some View {
        ZStack(alignment: .bottomLeading) {
            Text(viewModel.selectedEmojis[i])
                .font(.system(size: size.width * 0.78))
                .frame(width: size.width, height: size.height)

            Button {
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    viewModel.selectedEmojis.remove(at: i)
                }
            } label: {
                Image("deleteIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(.leading, size.width * (64.0 / 96.0))
            .padding(.bottom, size.height * (19.0 / 144.0))
        }
    }

    private func addEmojiCell(size: CGSize) -> some View {
        Button {
            isEmojiKeyboardFocused = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: size.width * 0.22, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color("Neutral-800")))
                .frame(width: size.width, height: size.height)
        }
        .buttonStyle(.plain)
    }

    // Rule 2: random cycling emoji with radial glow — creator picks emoji later in MemberEmojiSetupView
    private var singleEmojiArea: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.08), Color.clear]),
                center: .center,
                startRadius: 0,
                endRadius: 140
            )
            .frame(width: 280, height: 280)

            Text(randomEmoji)
                .font(.system(size: 120))
        }
        .onReceive(randomEmojiTimer) { _ in
            guard viewModel.emojiRule == .anyEmoji else { return }
            randomEmoji = randomEmojiPool.randomElement() ?? "🎉"
        }
    }

    // MARK: - Rules section

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rules")
                .appFont(AppFont.labelM)
                .foregroundColor(.white)
                .padding(.leading, 4)

            HStack(spacing: 6) {
                ruleCard(
                    imageName: viewModel.emojiRule == .selectedOnly ? "selectedEmojiSelected" : "selectedEmojiNotSelected",
                    title: "Selected\nemojis only",
                    isSelected: viewModel.emojiRule == .selectedOnly
                ) {
                    viewModel.emojiRule = .selectedOnly
                }

                ruleCard(
                    imageName: viewModel.emojiRule == .anyEmoji ? "anyEmojiSelected" : "anyEmojiNotSelected",
                    title: "Anyone can\nchoose any emoji",
                    isSelected: viewModel.emojiRule == .anyEmoji
                ) {
                    viewModel.emojiRule = .anyEmoji
                }
            }
        }
    }

    private func ruleCard(imageName: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .padding(.top, 13)
                    .padding(.leading, 13)

                Text(title)
                    .appFont(AppFont.labelM)
                    .foregroundColor(isSelected ? .white : Color("Neutral-500"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 15)
                    .padding(.bottom, 17)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 115, alignment: .leading)
            .background(Color("Neutral-900"))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color("White") : Color("Neutral-700"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Choose Emoji button

    private var createButton: some View {
        Button {
            showOwnerEmojiSetup = true
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color("Neutral-800"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Choose Emoji")
                    .appFont(AppFont.buttonL)
                    .foregroundColor(viewModel.isEmojiSetupValid ? Color("Neutral-1000") : Color("Neutral-500"))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(viewModel.isEmojiSetupValid ? Color("Green-300") : Color("Neutral-800"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .disabled(!viewModel.isEmojiSetupValid || viewModel.isLoading)
    }
}

private extension EmojiSetupView {
    enum EmojiLayoutItem: Hashable {
        case emoji(Int)
        case add
    }

    struct SelectedEmojiLayout {
        let itemSize: CGSize
        let itemSpacing: CGFloat
        let rowSpacing: CGFloat
        let rows: [[EmojiLayoutItem]]
    }

    var selectedEmojiLayout: SelectedEmojiLayout {
        let count = viewModel.selectedEmojis.count
        let usesLargeCells = count <= 5
        let itemSize = usesLargeCells ? CGSize(width: 96, height: 144) : CGSize(width: 75, height: 113)
        let itemSpacing: CGFloat = usesLargeCells ? 8 : 10
        let rowSpacing: CGFloat = 0

        var items = viewModel.selectedEmojis.indices.map(EmojiLayoutItem.emoji)
        if count < 10 {
            items.append(.add)
        }

        return SelectedEmojiLayout(
            itemSize: itemSize,
            itemSpacing: itemSpacing,
            rowSpacing: rowSpacing,
            rows: emojiRows(for: items, emojiCount: count)
        )
    }

    func emojiRows(for items: [EmojiLayoutItem], emojiCount: Int) -> [[EmojiLayoutItem]] {
        switch emojiCount {
        case 1, 2:
            return [items]
        case 3:
            return [Array(items.prefix(3)), Array(items.suffix(1))]
        case 4:
            return [Array(items.prefix(3)), Array(items.suffix(2))]
        case 5:
            return [Array(items.prefix(3)), Array(items.suffix(3))]
        case 6:
            return [Array(items.prefix(4)), Array(items.suffix(3))]
        case 7:
            return [Array(items.prefix(4)), Array(items.dropFirst(4).prefix(4))]
        case 8:
            return [Array(items.prefix(4)), Array(items.dropFirst(4).prefix(4)), Array(items.suffix(1))]
        case 9:
            return [Array(items.prefix(4)), Array(items.dropFirst(4).prefix(4)), Array(items.suffix(2))]
        case 10:
            return [Array(items.prefix(4)), Array(items.dropFirst(4).prefix(4)), Array(items.suffix(2))]
        default:
            var rows: [[EmojiLayoutItem]] = []
            var remaining = items[...]
            while !remaining.isEmpty {
                let take = min(4, remaining.count)
                rows.append(Array(remaining.prefix(take)))
                remaining = remaining.dropFirst(take)
            }
            return rows
        }
    }
}

#Preview {
    let viewModel = CreateChallengeViewModel()
    viewModel.emojiRule = .selectedOnly
    viewModel.selectedEmojis = ["🔥", "👑", "🍗", "🍄", "🐶", "🐷", "🌷", "🍊"]

    return EmojiSetupView(viewModel: viewModel)
}
