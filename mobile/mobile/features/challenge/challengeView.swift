
import SwiftUI
import SpriteKit

struct ChallengeView: View {
    @StateObject private var viewModel = ChallengeViewModel()

    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    // Dropdown Button
                    Button(action: {
                        viewModel.toggleDropdown()
                    }) {
                        HStack(spacing: 8) {
                            Text(viewModel.selectedCategory)
                                .appText(AppFont.title1)
                                .foregroundColor(AppColors.textWhite)

                            Image(systemName: "chevron.down")
                                .foregroundColor(AppColors.textWhite)
                                .font(.system(size: 10, weight: .bold))
                                .rotationEffect(.degrees(viewModel.isDropdownPresented ? 180 : 0))
                                .animation(.easeInOut(duration: 0.2), value: viewModel.isDropdownPresented)
                        }
                    }
                    .anchorPreference(key: DropdownBoundsPreferenceKey.self, value: .bounds) { $0 }

                    Spacer()

                    // Search Button
                    Button {
                        // Search action
                    } label: {
                         Image(systemName: "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(12)
                            .background(AppColors.neutral900)
                            .clipShape(Circle())
                            .foregroundColor(AppColors.textWhite)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .zIndex(1)

                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.textWhite))
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage, viewModel.challenges.isEmpty {
                    Spacer()
                    Text(errorMessage)
                        .appText(AppFont.captionM)
                        .foregroundColor(AppColors.neutral400)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                } else if viewModel.challenges.isEmpty {
                    Spacer()
                    Text("No challenges yet")
                        .appText(AppFont.captionM)
                        .foregroundColor(AppColors.neutral400)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(viewModel.challenges) { challenge in
                                ChallengeCard(challenge: challenge)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .dropdownOverlay(
            isPresented: $viewModel.isDropdownPresented,
            options: viewModel.categories,
            selection: $viewModel.selectedCategory,
            onSelect: { category in
                viewModel.selectCategory(category)
            },
            labelTitle: { $0 }
        )
    }
}

struct ChallengeCard: View {
    let challenge: ChallengeItem

    var body: some View {
        HStack(spacing: 0) {
            // Left Content
            VStack(alignment: .leading, spacing: 0) {

                // Date Pill (Green)
                Text(challenge.dateRangeText)
                    .appText(AppFont.captionS)
                    .foregroundColor(Color.black)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(AppColors.green300)
                    .clipShape(Capsule())
                    .padding(.bottom, 8)

                // Title
                Text(challenge.title)
                    .appText(AppFont.title3)
                    .foregroundColor(AppColors.textWhite)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .padding(.bottom, 12)

                // Meta info (Calendar icon + Frequency)
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundColor(AppColors.neutral400)

                    Text(challenge.frequency)
                        .appText(AppFont.captionS)
                        .foregroundColor(AppColors.neutral400)
                }
                .padding(.bottom, 16)

                // Participants Pile
                HStack(spacing: -8) {
                    let displayMembers = Array(challenge.members.prefix(4))
                    ForEach(Array(displayMembers.enumerated()), id: \.offset) { index, member in
                        AvatarView(imageURLOrName: member.avatarUrl, size: 28)
                            .overlay(
                               Circle().stroke(AppColors.neutral900, lineWidth: 2)
                            )
                            .zIndex(Double(displayMembers.count - index))
                    }

                    // Overflow count
                    if challenge.memberCount > 4 {
                        Text("+\(challenge.memberCount - 4)")
                            .appText(AppFont.captionM)
                            .foregroundColor(AppColors.white)
                            .padding(.leading, 12)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 16)

            // Right: Shaker Preview
            ChallengeShakerPreview(challenge: challenge)
                .frame(width: 100, height: 100)
        }
        .padding(16)
        .background(AppColors.neutral900)
        .cornerRadius(16)
    }
}

// MARK: - Challenge Shaker Preview (mirrors FriendCardView's ShakerView pattern)
struct ChallengeShakerPreview: View {
    let challenge: ChallengeItem

    @State private var scene = ShakerScene(size: .zero)
    @State private var lidColors: [Color] = [.black, .gray]
    @State private var lidOpacity: Double = 0

    // Lid position & size (matching ShakerView ratios)
    private let lidHeightRatio:   CGFloat = 46.0 / 270.0
    private let lidCornerRatio:   CGFloat = 13.0 / 270.0
    private let lidTopInsetRatio: CGFloat = 23.5 / 270.0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let jarSize = CGSize(width: side, height: side)

            ZStack {
                // Jar base
                Image("jarBase")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)

                // Lid gradient (when completed)
                Rectangle()
                    .fill(
                        LinearGradient(colors: lidColors,
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .frame(
                        width: jarSize.width,
                        height: jarSize.height * lidHeightRatio
                    )
                    .cornerRadius(jarSize.height * lidCornerRatio)
                    .offset(y: -jarSize.height / 2 + jarSize.height * lidTopInsetRatio)
                    .opacity(lidOpacity)
                    .allowsHitTesting(false)

                // SpriteKit emoji scene
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .frame(width: jarSize.width, height: jarSize.height)

                // Jar lid overlay image
                Image("glitchLid")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .onAppear {
                if scene.size == .zero {
                    scene = ShakerScene(size: jarSize)
                }

                // Preview mode: small emojis, constant gravity, no device motion
                scene.setEmojiScale(24.0 / 54.0)
                scene.setMotionEnabled(false)
                scene.configureBoundaries(inset: 12, lidHeight: 40, bottomExtraDepth: 10)
                scene.useConstantGravity(18)
                scene.setHapticsEnabled(false)

                // Clear and re-add emojis
                scene.resetScene()
                for emoji in challenge.shakerUserEmojis {
                    scene.addEmoji(emoji, for: UUID())
                }

                // Settle emojis to the bottom for preview
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scene.settleAllToBottom()
                }

                // Lid color
                if challenge.shakerIsCompleted {
                    if let c0 = Color(hex: challenge.shakerLidColorStart),
                       let c1 = Color(hex: challenge.shakerLidColorEnd) {
                        lidColors = [c0, c1]
                    }
                    lidOpacity = 1
                } else {
                    lidOpacity = 0
                }
            }
        }
    }
}
