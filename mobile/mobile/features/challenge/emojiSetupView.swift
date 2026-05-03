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
    @State private var emojiGridCellSize: CGFloat = 70

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
                    .onAppear { emojiGridCellSize = (screen.size.width - 96) / 4 }

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
                                    .foregroundColor(Color("Neutral-400"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .frame(height: 103)

                        createButton
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
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

    // Rule 1: grid of selected emojis + inline add button
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
            let count = viewModel.selectedEmojis.count
            let cell = min(emojiGridCellSize, 88)
            let numRows: Int = {
                if count >= 9 { return 3 }
                return Int(ceil(Double(count + 1) / 4.0))
            }()
            let gridHeight = CGFloat(numRows) * cell + CGFloat(numRows - 1) * 16

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cell), spacing: 16), count: 4),
                spacing: 16
            ) {
                ForEach(0..<min(count, 8), id: \.self) { i in
                    emojiCell(at: i, size: cell)
                }
                // 9th/10th go on a centered row using blank bookends
                if count >= 9 {
                    Color.clear.frame(width: cell, height: cell)
                    emojiCell(at: 8, size: cell)
                }
                if count == 10 {
                    emojiCell(at: 9, size: cell)
                    Color.clear.frame(width: cell, height: cell)
                } else if count < 10 {
                    Button {
                        isEmojiKeyboardFocused = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: cell, height: cell)
                            .background(Circle().fill(Color("Neutral-800")))
                    }
                    .buttonStyle(.plain)
                    if count >= 9 {
                        Color.clear.frame(width: cell, height: cell)
                    }
                }
            }
            .frame(height: gridHeight)
        }
    }

    private func emojiCell(at i: Int, size: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Text(viewModel.selectedEmojis[i])
                .font(.system(size: size * 0.75))
                .frame(width: size, height: size)

            Button {
                viewModel.selectedEmojis.remove(at: i)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: size * 0.32))
                    .foregroundColor(Color("Red-500"))
                    .background(Circle().fill(Color("Neutral-1000")).padding(2))
            }
            .buttonStyle(.plain)
        }
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

            HStack(spacing: 12) {
                ruleCard(
                    icon: "😊",
                    title: "Selected\nemojis only",
                    isSelected: viewModel.emojiRule == .selectedOnly
                ) {
                    viewModel.emojiRule = .selectedOnly
                }

                ruleCard(
                    icon: "🤙",
                    title: "Anyone can\nchoose any emoji",
                    isSelected: viewModel.emojiRule == .anyEmoji
                ) {
                    viewModel.emojiRule = .anyEmoji
                }
            }
        }
    }

    private func ruleCard(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Text(icon)
                    .font(.system(size: 22))

                Text(title)
                    .appFont(AppFont.labelM)
                    .foregroundColor(isSelected ? .white : Color("Neutral-500"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 115, alignment: .leading)
            .padding(14)
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
                    .appFont(AppFont.title3)
                    .foregroundColor(viewModel.isEmojiSetupValid ? Color("Neutral-1000") : Color("Neutral-500"))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(viewModel.isEmojiSetupValid ? Color("Green-300") : Color("Neutral-800"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .disabled(!viewModel.isEmojiSetupValid || viewModel.isLoading)
    }
}
