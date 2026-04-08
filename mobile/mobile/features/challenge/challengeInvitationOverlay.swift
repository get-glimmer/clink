import SwiftUI
import Combine

private enum ChallengeInvitationStage {
    case intro
    case opening
    case revealed
}

struct ChallengeInvitationOverlay: View {
    let invite: InvitedChallengeItem
    let onClose: () -> Void

    @State private var stage: ChallengeInvitationStage = .intro
    @State private var envelopeTiltAngle: Double = -1
    @State private var openEnvelopeOpacity: Double = 0
    @State private var closedEnvelopeOpacity: Double = 1
    @State private var letterLift: CGFloat = 0
    @State private var envelopeDrop: CGFloat = 0
    @State private var detailTextOpacity: Double = 0

    private let wobbleTimer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    private let envelopeWidth: CGFloat = 302
    private let envelopeTopHeight: CGFloat = 171
    private let envelopeBottomHeight: CGFloat = 275
    private let letterWidth: CGFloat = 278
    private let letterHeight: CGFloat = 231
    private let envelopeCanvasHeight: CGFloat = 420
    // Keep the whole envelope group visually centered on screen.
    private let envelopeGroupYOffset: CGFloat = -52
    private let openedEnvelopeYOffset: CGFloat = -36

    var body: some View {
        ZStack {
            DarkBlurView(style: .systemChromeMaterialDark)
                .ignoresSafeArea()
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 36)

                Group {
                    switch stage {
                    case .intro:
                        introContent
                    case .opening, .revealed:
                        openedEnvelopeContent
                    }
                }
                .offset(y: envelopeGroupYOffset)

                Spacer()

                if stage == .intro {
                    openInvitationButton
                        .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 16)
        }
        .onReceive(wobbleTimer) { _ in
            guard stage == .intro else { return }
            withAnimation(.easeInOut(duration: 0.16)) {
                envelopeTiltAngle = (envelopeTiltAngle == -1) ? 1 : -1
            }
        }
    }
}

private extension ChallengeInvitationOverlay {
    var topBar: some View {
        HStack {
            Color.clear
                .frame(width: 26, height: 26)

            Spacer()

            if stage == .intro {
                Text("Challenge Invitation")
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.title2)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.neutral300)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 30)
    }

    var introContent: some View {
        let closedEnvelopeCenterY = (envelopeBottomHeight - envelopeTopHeight) / 2
        let inviterTextY = closedEnvelopeCenterY - (envelopeTopHeight / 2) - 30
        let messageY = closedEnvelopeCenterY + (envelopeTopHeight / 2) + 30

        return ZStack {
            // Keep closed envelope at the exact same coordinates as opened top layer.
            Image("envelopeClosed")
                .offset(y: closedEnvelopeCenterY)
                .rotationEffect(.degrees(envelopeTiltAngle))

            Text("\(inviterDisplayName) invited you to join!")
                .foregroundColor(AppColors.neutral100)
                .appText(AppFont.title2)
                .offset(y: inviterTextY)

            Text(invitationMessage)
                .foregroundColor(AppColors.neutral300)
                .appText(AppFont.body1)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 270)
                .offset(y: messageY)
        }
        .frame(width: envelopeWidth, height: envelopeCanvasHeight)
    }

    var openInvitationButton: some View {
        Button(action: openInvitation) {
            Text("Open Invitation")
                .foregroundColor(AppColors.neutral1000)
                .appText(AppFont.buttonL)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppColors.green300)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 370)
    }

    var openedEnvelopeContent: some View {
        let closedEnvelopeCenterY = (envelopeBottomHeight - envelopeTopHeight) / 2

        return ZStack {
            // Fade out closed envelope while open layers fade in.
            if stage == .opening || closedEnvelopeOpacity > 0.01 {
                Image("envelopeClosed")
                    .offset(y: closedEnvelopeCenterY)
                    .rotationEffect(.degrees(envelopeTiltAngle))
                    .opacity(closedEnvelopeOpacity)
            }

            // Bottom-most layer
            Image("envelopeBottomLayer")
                .offset(y: envelopeDrop)
                .opacity(openEnvelopeOpacity)

            // Middle layer (letter), clipped only below envelope bottom edge.
            letterPaperView
                .opacity(openEnvelopeOpacity)

            // Top-most layer
            Image("envelopeTopLayer")
                // Align bottom edge with envelopeBottomLayer's bottom edge.
                .offset(y: envelopeDrop + (envelopeBottomHeight - envelopeTopHeight) / 2)
                .opacity(openEnvelopeOpacity)
        }
        .frame(width: envelopeWidth, height: envelopeCanvasHeight)
        .offset(y: openedEnvelopeYOffset)
        .onAppear {
            if stage == .opening {
                scheduleRevealAnimation()
            }
        }
    }

    var letterPaperView: some View {
        let bottomEdgeY = envelopeDrop + (envelopeBottomHeight / 2)

        return Image("letterPaper")
            .overlay(alignment: .top) {
                VStack(spacing: 12) {
                    Text(invite.dateRangeText)
                        .foregroundColor(AppColors.neutral1000)
                        .appText(AppFont.labelS)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.green300)
                        .cornerRadius(999)

                    Text(invite.title)
                        .foregroundColor(AppColors.textWhite)
                        .appText(AppFont.title2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 170)
                }
                .padding(.top, 38)
                .opacity(detailTextOpacity)
            }
            .offset(y: 84 + letterLift)
            .mask(
                Rectangle()
                    .frame(width: envelopeWidth, height: 2000)
                    .offset(y: bottomEdgeY - 1000)
            )
    }

    var inviterDisplayName: String {
        let name = invite.inviterName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Someone" : name
    }

    var invitationMessage: String {
        let trimmed = invite.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Join this challenge with me!" : trimmed
    }

    func openInvitation() {
        guard stage == .intro else { return }
        stage = .opening
        withAnimation(.easeInOut(duration: 0.75)) {
            openEnvelopeOpacity = 1
            closedEnvelopeOpacity = 0
        }
    }

    func scheduleRevealAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard stage == .opening else { return }
            stage = .revealed
            withAnimation(.easeInOut(duration: 0.9)) {
                letterLift = -86
                envelopeDrop = 30
                detailTextOpacity = 1
            }
        }
    }
}
