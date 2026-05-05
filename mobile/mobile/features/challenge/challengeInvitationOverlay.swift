import SwiftUI
import Combine
import Supabase

private enum ChallengeInvitationStage {
    case intro
    case opening
    case revealed
    case details
}

private struct InviteChallengeDetails: Decodable {
    let id: UUID
    let description: String?
    let repeat_type: String
    let weekly_days: [Int]?
    let monthly_days: [Int]?
}

private struct InviteTaskRow: Decodable {
    let task_title: String?
    let sortorder: Int?
}

private struct MemberEmojiRow: Decodable {
    let member_emoji: String?
    let left_at: String?
}

private struct JoinMemberUpsert: Encodable {
    let challenge_id: UUID
    let user_id: UUID
    let role: String
    let member_emoji: String
}

@MainActor
private final class ChallengeInvitationOverlayViewModel: ObservableObject {
    @Published var challengeDescription: String
    @Published var repeatType: String = "everyday"
    @Published var weeklyDays: [Int] = []
    @Published var monthlyDays: [Int] = []
    @Published var tasks: [String] = []
    @Published var usedEmojis: Set<String> = []

    @Published var selectedEmoji: String = ""
    @Published var emojiInUseError: Bool = false
    @Published var isJoining: Bool = false
    @Published var errorMessage: String?

    let invite: InvitedChallengeItem

    private var client: SupabaseClient? { SupabaseClientManager.shared.client }

    init(invite: InvitedChallengeItem) {
        self.invite = invite
        self.challengeDescription = invite.description ?? ""
        if invite.emojiRule == .selectedOnly,
           let first = invite.presetEmojis.first {
            selectedEmoji = first
        }
    }

    func load() async {
        guard let client else { return }
        do {
            let details: [InviteChallengeDetails] = try await client
                .from("challenges")
                .select("id, description, repeat_type, weekly_days, monthly_days")
                .eq("id", value: invite.challengeId.uuidString)
                .limit(1)
                .execute()
                .value

            if let info = details.first {
                challengeDescription = info.description ?? ""
                repeatType = info.repeat_type
                weeklyDays = info.weekly_days ?? []
                monthlyDays = info.monthly_days ?? []
            }

            let taskRows: [InviteTaskRow] = try await client
                .from("challenge_task")
                .select("task_title, sortorder")
                .eq("challenge_id", value: invite.challengeId.uuidString)
                .order("sortorder", ascending: true)
                .execute()
                .value

            tasks = taskRows.compactMap { row in
                let title = row.task_title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return title.isEmpty ? nil : title
            }

            let memberRows: [MemberEmojiRow] = try await client
                .from("challenge_members")
                .select("member_emoji, left_at")
                .eq("challenge_id", value: invite.challengeId.uuidString)
                .execute()
                .value

            usedEmojis = Set(
                memberRows
                    .filter { $0.left_at == nil }
                    .compactMap { row in
                        let value = row.member_emoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        return value.isEmpty ? nil : value
                    }
            )

            if !selectedEmoji.isEmpty && usedEmojis.contains(selectedEmoji) {
                selectedEmoji = ""
            }
        } catch {
            errorMessage = "Failed to load invitation details: \(error.localizedDescription)"
        }
    }

    func selectEmoji(_ emoji: String) {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if usedEmojis.contains(trimmed) {
            emojiInUseError = true
            selectedEmoji = ""
            return
        }

        selectedEmoji = trimmed
        emojiInUseError = false
    }

    func joinChallenge(onJoined: @escaping () -> Void) async {
        let picked = selectedEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !picked.isEmpty, !isJoining else { return }

        if usedEmojis.contains(picked) {
            emojiInUseError = true
            return
        }

        guard let client else {
            errorMessage = "Client unavailable"
            return
        }

        isJoining = true
        errorMessage = nil

        do {
            let session = try await client.auth.session
            let userId = session.user.id

            let row = JoinMemberUpsert(
                challenge_id: invite.challengeId,
                user_id: userId,
                role: "member",
                member_emoji: picked
            )

            try await client
                .from("challenge_members")
                .upsert(row)
                .execute()

            do {
                try await client
                    .from("challenge_invites")
                    .update(["status": "accepted"])
                    .eq("id", value: invite.id.uuidString)
                    .execute()
            } catch {
                try await client
                    .from("challenge_invites")
                    .delete()
                    .eq("id", value: invite.id.uuidString)
                    .execute()
            }

            onJoined()
        } catch {
            let msg = error.localizedDescription
            if msg.localizedCaseInsensitiveContains("duplicate") ||
                msg.localizedCaseInsensitiveContains("unique") {
                emojiInUseError = true
                errorMessage = "This emoji is already in use."
            } else {
                errorMessage = "Failed to join challenge: \(msg)"
            }
        }

        isJoining = false
    }

    var canJoin: Bool {
        !selectedEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !emojiInUseError && !isJoining
    }

    var repeatInfoText: String {
        let rt = repeatType.lowercased()
        switch rt {
        case "everyday", "daily":
            return "Every day"
        case "weekly":
            let names = weeklyDays
                .map { weekdayLabel($0) }
                .filter { !$0.isEmpty }
            return names.isEmpty ? "Every week" : "Every \(names.joined(separator: ", "))"
        case "monthly":
            let sorted = monthlyDays.sorted()
            let labels = sorted.map { ordinal($0) }
            return labels.isEmpty ? "Every month" : "\(labels.joined(separator: ", ")) of every month"
        default:
            return invite.frequency
        }
    }

    private func weekdayLabel(_ raw: Int) -> String {
        switch raw {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return ""
        }
    }

    private func ordinal(_ value: Int) -> String {
        let absValue = abs(value)
        let mod100 = absValue % 100
        if mod100 == 11 || mod100 == 12 || mod100 == 13 {
            return "\(value)th"
        }

        switch absValue % 10 {
        case 1: return "\(value)st"
        case 2: return "\(value)nd"
        case 3: return "\(value)rd"
        default: return "\(value)th"
        }
    }
}

struct ChallengeInvitationOverlay: View {
    let invite: InvitedChallengeItem
    let onClose: () -> Void
    let onJoined: (() -> Void)?

    @StateObject private var viewModel: ChallengeInvitationOverlayViewModel

    @State private var stage: ChallengeInvitationStage = .intro
    @State private var envelopeTiltAngle: Double = -1
    @State private var openEnvelopeOpacity: Double = 0
    @State private var closedEnvelopeOpacity: Double = 1
    @State private var letterLift: CGFloat = 0
    @State private var envelopeDrop: CGFloat = 0
    @State private var detailTextOpacity: Double = 0

    @State private var isDescriptionExpanded = false
    @State private var isTaskExpanded = false

    @State private var anyEmojiCustomSlot = ""
    @State private var pickedEmojiFromKeyboard = ""
    @State private var isEmojiFieldFocused = false

    private let wobbleTimer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    private let envelopeWidth: CGFloat = 302
    private let envelopeTopHeight: CGFloat = 171
    private let envelopeBottomHeight: CGFloat = 275
    private let envelopeCanvasHeight: CGFloat = 420
    private let envelopeGroupYOffset: CGFloat = -52
    private let openedEnvelopeYOffset: CGFloat = -36

    init(
        invite: InvitedChallengeItem,
        onClose: @escaping () -> Void,
        onJoined: (() -> Void)? = nil
    ) {
        self.invite = invite
        self.onClose = onClose
        self.onJoined = onJoined
        _viewModel = StateObject(wrappedValue: ChallengeInvitationOverlayViewModel(invite: invite))
    }

    var body: some View {
        ZStack {
            DarkBlurView(style: .systemChromeMaterialDark)
                .ignoresSafeArea()
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if stage == .details {
                    detailsContent
                        .transition(.opacity)
                } else {
                    Spacer(minLength: 36)

                    Group {
                        switch stage {
                        case .intro:
                            introContent
                        case .opening, .revealed:
                            openedEnvelopeContent
                        case .details:
                            EmptyView()
                        }
                    }
                    .offset(y: envelopeGroupYOffset)

                    Spacer()

                    if stage == .intro {
                        openInvitationButton
                            .padding(.bottom, 24)
                    }
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
        .onAppear {
            Task { await viewModel.load() }
        }
        .onChange(of: pickedEmojiFromKeyboard) { value in
            guard let emoji = value.firstEmoji, !emoji.isEmpty else { return }
            anyEmojiCustomSlot = emoji
            viewModel.selectEmoji(emoji)
            pickedEmojiFromKeyboard = ""
            isEmojiFieldFocused = false
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard stage == .revealed else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                stage = .details
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
            if stage == .opening || closedEnvelopeOpacity > 0.01 {
                Image("envelopeClosed")
                    .offset(y: closedEnvelopeCenterY)
                    .rotationEffect(.degrees(envelopeTiltAngle))
                    .opacity(closedEnvelopeOpacity)
            }

            Image("envelopeBottomLayer")
                .offset(y: envelopeDrop)
                .opacity(openEnvelopeOpacity)

            letterPaperView
                .opacity(openEnvelopeOpacity)

            Image("envelopeTopLayer")
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

    var detailsContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)

            Text("\(inviterDisplayName) invited you to join!")
                .foregroundColor(AppColors.neutral100)
                .appText(AppFont.title2)
                .multilineTextAlignment(.center)

            Text(invitationMessage)
                .foregroundColor(AppColors.neutral300)
                .appText(AppFont.body1)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .frame(maxWidth: 329)

            letterSectionCard
                .padding(.top, 28)
                .padding(.bottom, 16)

            joinChallengeButton
                .padding(.bottom, 18)

            HiddenEmojiTextField(text: $pickedEmojiFromKeyboard, isFirstResponder: $isEmojiFieldFocused)
                .frame(width: 1, height: 1)
                .opacity(0.02)
                .allowsHitTesting(false)
        }
    }

    var letterSectionCard: some View {
        ZStack(alignment: .topLeading) {
            Image("letterPaperExpanded")

            GeometryReader { geo in
                let contentWidth = max(0, geo.size.width - 40)
                let contentHeight = max(0, geo.size.height - 68) // 29(top) + 39(bottom)
                let shouldScroll = isDescriptionExpanded || isTaskExpanded

                Group {
                    if shouldScroll {
                        ScrollView(showsIndicators: false) {
                            invitationLetterBody
                                .frame(width: contentWidth, alignment: .leading)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } else {
                        invitationLetterBody
                            .frame(width: contentWidth, alignment: .leading)
                    }
                }
                .frame(width: geo.size.width, height: contentHeight, alignment: .top)
                .clipped()
                .padding(.top, 29)
            }

            if viewModel.emojiInUseError {
                Text("This emoji is already in use.")
                    .foregroundColor(Color("Red-300"))
                    .appText(AppFont.captionS)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 36)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: 370)
    }

    var invitationLetterBody: some View {
        VStack(alignment: .leading, spacing: 24) {
            challengeGeneralInfoSection
            taskSection
            pickEmojiSection
        }
    }

    var challengeGeneralInfoSection: some View {
        let showDescriptionMore = !isDescriptionExpanded && viewModel.challengeDescription.count > 110

        return VStack(alignment: .leading, spacing: 10) {
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

            ZStack(alignment: .bottomTrailing) {
                Text(viewModel.challengeDescription)
                    .foregroundColor(AppColors.neutral300)
                    .appText(AppFont.body2)
                    .lineLimit(isDescriptionExpanded ? nil : 3)
                    .truncationMode(.tail)
                    .frame(maxWidth: 329, alignment: .leading)
                    .overlay(alignment: .bottomTrailing) {
                        if showDescriptionMore {
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 80, height: 22)
                                .blendMode(.destinationOut)
                        }
                    }
                    .compositingGroup()

                if showDescriptionMore {
                    Button("...more") {
                        isDescriptionExpanded = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.neutral400)
                    .appText(AppFont.captionXS_M)
                }
            }
        }
    }

    var taskSection: some View {
        let source = viewModel.tasks
        let rows: [String?]
        if isTaskExpanded {
            rows = source.map { Optional($0) }
        } else {
            let prefix = Array(source.prefix(2))
            if prefix.count == 1 {
                rows = [prefix[0], nil]
            } else if prefix.count == 0 {
                rows = [nil, nil]
            } else {
                rows = [prefix[0], prefix[1]]
            }
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Task")
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.labelM)

            Text(viewModel.repeatInfoText)
                .foregroundColor(AppColors.neutral400)
                .appText(AppFont.captionM)

            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, title in
                    if let title {
                        HStack(spacing: 12) {
                            Image("checkboxFilled")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)

                            if !isTaskExpanded && source.count > 2 && index == 1 {
                                ZStack(alignment: .trailing) {
                                    Text(title)
                                        .foregroundColor(AppColors.textWhite)
                                        .appText(AppFont.captionM)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .overlay(alignment: .trailing) {
                                            Rectangle()
                                                .fill(Color.black)
                                                .frame(width: 78, height: 18)
                                                .blendMode(.destinationOut)
                                        }
                                        .compositingGroup()

                                    Button("...more") {
                                        isTaskExpanded = true
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(AppColors.neutral400)
                                    .appText(AppFont.captionXS_M)
                                }
                            } else {
                                Text(title)
                                    .foregroundColor(AppColors.textWhite)
                                    .appText(AppFont.captionM)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
                    }
                }
            }
        }
    }

    var pickEmojiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick your emoji")
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.labelM)
                .padding(.bottom, 8)

            if invite.emojiRule == .selectedOnly {
                selectedOnlyEmojiGrid
            } else {
                anyEmojiRow
            }
        }
    }

    var selectedOnlyEmojiGrid: some View {
        let items = invite.presetEmojis
        let spacing: CGFloat = 31
        let columns = Array(repeating: GridItem(.fixed(36), spacing: spacing), count: 5)
        let height: CGFloat = items.count <= 5 ? 36 : 93

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 21) {
            ForEach(items, id: \.self) { emoji in
                emojiCell(emoji: emoji)
            }
        }
        .frame(width: 304, height: height, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var anyEmojiRow: some View {
        let quickEmojis: [String] = ["👍", "💖", "👏", "🔥", "🎉"]
        let spacing: CGFloat = (329.0 - (36.0 * 6.0)) / 5.0

        return HStack(spacing: spacing) {
            ForEach(quickEmojis, id: \.self) { emoji in
                emojiCell(emoji: emoji)
            }

            if anyEmojiCustomSlot.isEmpty {
                Button {
                    isEmojiFieldFocused = true
                } label: {
                    Image("addEmoji")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            } else {
                customEmojiSlotButton(emoji: anyEmojiCustomSlot)
            }
        }
        .frame(width: 329, height: 36, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    func emojiCell(emoji: String) -> some View {
        let isSelected = viewModel.selectedEmoji == emoji
        let isUsed = viewModel.usedEmojis.contains(emoji)

        Button {
            viewModel.selectEmoji(emoji)
        } label: {
            Text(emoji)
                .font(.system(size: 32))
                .frame(width: 36, height: 36)
                .background(
                    Group {
                        if isSelected {
                            ZStack {
                                Color.white.opacity(0.32)
                                    .frame(width: 33, height: 33)
                                    .mask(
                                        Text(emoji)
                                            .font(.system(size: 32))
                                    )
                                    .blur(radius: 6)
                                Color.white.opacity(0.18)
                                    .frame(width: 33, height: 33)
                                    .mask(
                                        Text(emoji)
                                            .font(.system(size: 34))
                                    )
                                    .blur(radius: 9)
                            }
                        }
                    }
                )
                .overlay {
                    if isUsed {
                        Image("diagonalWhiteLine")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    }
                }
        }
        .buttonStyle(.plain)
        .zIndex(isSelected ? 10 : 0)
    }

    @ViewBuilder
    func customEmojiSlotButton(emoji: String) -> some View {
        let isSelected = viewModel.selectedEmoji == emoji
        let isUsed = viewModel.usedEmojis.contains(emoji)

        Button {
            isEmojiFieldFocused = true
        } label: {
            Text(emoji)
                .font(.system(size: 32))
                .frame(width: 36, height: 36)
                .background(
                    Group {
                        if isSelected {
                            ZStack {
                                Color.white.opacity(0.22)
                                    .frame(width: 36, height: 36)
                                    .mask(
                                        Text(emoji)
                                            .font(.system(size: 32))
                                    )
                                    .blur(radius: 8)
                                Color.white.opacity(0.13)
                                    .frame(width: 40, height: 40)
                                    .mask(
                                        Text(emoji)
                                            .font(.system(size: 34))
                                    )
                                    .blur(radius: 12)
                            }
                        }
                    }
                )
                .overlay {
                    if isUsed {
                        Image("diagonalWhiteLine")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    }
                }
        }
        .buttonStyle(.plain)
        .zIndex(isSelected ? 10 : 0)
    }

    var joinChallengeButton: some View {
        Button {
            Task {
                await viewModel.joinChallenge {
                    onJoined?()
                    onClose()
                }
            }
        } label: {
            if viewModel.isJoining {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.neutral600)
                    .cornerRadius(10)
            } else {
                Text("Join Challenge")
                    .foregroundColor(viewModel.canJoin ? AppColors.neutral1000 : AppColors.neutral500)
                    .appText(AppFont.buttonL)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(viewModel.canJoin ? AppColors.green300 : AppColors.neutral800)
                    .cornerRadius(10)
            }
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canJoin)
        .frame(maxWidth: 370)
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

private struct HiddenEmojiTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool

    private final class EmojiFirstTextField: UITextField {
        override var textInputContextIdentifier: String? { "" }
        override var textInputMode: UITextInputMode? {
            for mode in UITextInputMode.activeInputModes {
                if let lang = mode.primaryLanguage, lang == "emoji" { return mode }
            }
            return super.textInputMode
        }
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = EmojiFirstTextField(frame: .zero)
        tf.delegate = context.coordinator
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.isHidden = false
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
            if string.isEmpty { return true }
            parent.text.append(string)
            return false
        }
    }
}
