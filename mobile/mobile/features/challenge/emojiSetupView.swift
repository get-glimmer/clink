import SwiftUI
import MCEmojiPicker

// MARK: - Emoji picker anchor
//
// UIViewRepresentable gives us a UIView with correctly resolved UIKit frame coordinates.
// UIViewControllerRepresentable's UIViewController view frame is often zero at presentation
// time, causing the popover to anchor at the wrong position.

private struct EmojiPickerAnchor: UIViewRepresentable {
    @Binding var isPresented: Bool
    @Binding var selectedEmoji: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard isPresented, !context.coordinator.isPresenting else { return }
        context.coordinator.showPicker(from: uiView)
    }

    final class Coordinator: NSObject, MCEmojiPickerDelegate, UIPopoverPresentationControllerDelegate {
        var parent: EmojiPickerAnchor
        var isPresenting = false

        init(_ parent: EmojiPickerAnchor) { self.parent = parent }

        func showPicker(from anchor: UIView) {
            guard let hostVC = anchor.nearestViewController() else { return }
            isPresenting = true
            let picker = MCEmojiPickerViewController()
            picker.delegate = self
            picker.sourceView = anchor
            picker.arrowDirection = .down
            picker.customHeight = 380
            picker.horizontalInset = 0
            picker.isDismissAfterChoosing = true
            picker.selectedEmojiCategoryTintColor = .white
            picker.feedBackGeneratorStyle = .light
            hostVC.present(picker, animated: true) {
                // Set after presentation so popoverPresentationController is ready.
                picker.popoverPresentationController?.delegate = self
            }
        }

        func didGetEmoji(emoji: String) {
            parent.selectedEmoji = emoji
            parent.isPresented = false
            isPresenting = false
        }

        // Keep compact popover style on iPhone (same as MCEmojiPickerViewController's own impl).
        func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
            return .none
        }

        // Called on any dismissal — emoji selected or user swiped away.
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            parent.isPresented = false
            isPresenting = false
        }
    }
}

private extension UIView {
    func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}

struct EmojiSetupView: View {
    @ObservedObject var viewModel: CreateChallengeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showPicker = false
    @State private var pickerEmoji: String = ""
    @State private var showOwnerEmojiSetup = false

    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                Spacer()

                emojiArea
                    .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 16) {
                    rulesSection
                        .padding(.horizontal, 16)

                    if viewModel.emojiRule == .selectedOnly {
                        Text("Select at least \(viewModel.minEmojiCount) emoji\(viewModel.minEmojiCount == 1 ? "" : "s") for this challenge")
                            .appFont(AppFont.captionM)
                            .foregroundColor(Color("Neutral-400"))
                            .multilineTextAlignment(.center)
                    }

                    createButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }

        }
        .navBarHidden(true)
        .onChange(of: pickerEmoji) { emoji in
            guard !emoji.isEmpty, viewModel.emojiRule == .selectedOnly else { return }
            if viewModel.selectedEmojis.count < 10 {
                viewModel.selectedEmojis.append(emoji)
            }
            pickerEmoji = ""
        }
        .onChange(of: viewModel.needsOwnerEmojiSelection) { needs in
            if needs { showOwnerEmojiSetup = true }
        }
        .onChange(of: showOwnerEmojiSetup) { isShowing in
            if !isShowing && viewModel.needsOwnerEmojiSelection {
                viewModel.completeCreation()
            }
        }
        .fullScreenCover(isPresented: $showOwnerEmojiSetup) {
            if let challengeId = viewModel.createdChallengeId {
                MemberEmojiSetupView(
                    challengeId: challengeId,
                    emojiRule: viewModel.emojiRule,
                    presetEmojis: viewModel.selectedEmojis,
                    representativeEmoji: "",
                    isOwner: true
                )
            }
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
            // Empty state: large centered + button
            Button {
                showPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 120)
                    .background(Circle().fill(Color("Neutral-800")))
            }
            .buttonStyle(.plain)
            .overlay(EmojiPickerAnchor(isPresented: $showPicker, selectedEmoji: $pickerEmoji).allowsHitTesting(false))
        } else if viewModel.selectedEmojis.count == 10 {
            // Max emojis: 4 + 4 + 2 with the last row centered
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in emojiCell(at: i) }
                }
                HStack(spacing: 16) {
                    ForEach(4..<8, id: \.self) { i in emojiCell(at: i) }
                }
                HStack(spacing: 16) {
                    Spacer()
                    emojiCell(at: 8)
                    emojiCell(at: 9)
                    Spacer()
                }
            }
        } else {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.selectedEmojis.indices, id: \.self) { i in
                    emojiCell(at: i)
                }

                Button {
                    showPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color("Neutral-800")))
                }
                .buttonStyle(.plain)
                .frame(width: 100, height: 100)
                .overlay(EmojiPickerAnchor(isPresented: $showPicker, selectedEmoji: $pickerEmoji).allowsHitTesting(false))
            }
        }
    }

    private func emojiCell(at i: Int) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Text(viewModel.selectedEmojis[i])
                .font(.system(size: 75))
                .frame(width: 100, height: 100)

            Button {
                viewModel.selectedEmojis.remove(at: i)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color("Red-500"))
                    .background(Circle().fill(Color("Neutral-1000")).padding(2))
            }
            .buttonStyle(.plain)
        }
    }

    // Rule 2: purely decorative 🔥 with radial glow — creator picks emoji later in MemberEmojiSetupView
    private var singleEmojiArea: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.08), Color.clear]),
                center: .center,
                startRadius: 0,
                endRadius: 140
            )
            .frame(width: 280, height: 280)

            Text("🔥")
                .font(.system(size: 120))
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

    // MARK: - Create Challenge button

    private var createButton: some View {
        Button {
            Task { await viewModel.createChallenge() }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color("Neutral-800"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Create Challenge")
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
