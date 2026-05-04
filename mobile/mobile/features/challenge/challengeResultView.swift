import SwiftUI
import SpriteKit
import UIKit
import Supabase

// MARK: - UI Models

struct ChallengeResultParticipantUI: Identifiable {
    let id: UUID
    let name: String
    let avatarURL: String?
    let emoji: String
    let percent: Int
}

@MainActor
final class ChallengeResultViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var title = ""
    @Published var dateRangeText = ""
    @Published var subtitle = "Challenge completed together!"

    @Published var participantsCount = 0
    @Published var totalDays = 0
    @Published var overallPercent = 0
    @Published var myPercent = 0
    @Published var myEmoji = "✨"

    @Published var jarItems: [JarItemUI] = []
    @Published var lidColorStart: String?
    @Published var lidColorEnd: String?
    @Published var isSealed: Bool = false
    @Published var dreamTeam: [ChallengeResultParticipantUI] = []
    @Published var highlights: [ChallengeGalleryItemUI] = []

    let challengeId: UUID
    private let client = SupabaseClientManager.shared.client

    init(challengeId: UUID) {
        self.challengeId = challengeId
    }

    static func mock() -> ChallengeResultViewModel {
        let vm = ChallengeResultViewModel(challengeId: UUID())
        vm.title = "7-Day Meditation Challenge"
        vm.dateRangeText = "2/1 - 2/28"
        vm.subtitle = "Challenge completed together!"
        vm.participantsCount = 5
        vm.totalDays = 28
        vm.overallPercent = 70
        vm.myPercent = 98
        vm.myEmoji = "🦋"
        vm.jarItems = (0..<24).map { i in
            JarItemUI(id: UUID(), emoji: ["🦋", "🫐", "💬", "🌼"][i % 4])
        }
        vm.dreamTeam = [
            .init(id: UUID(), name: "Seeun Park",   avatarURL: nil, emoji: "🦋", percent: 98),
            .init(id: UUID(), name: "Eunsoo Cho",   avatarURL: nil, emoji: "💬", percent: 85),
            .init(id: UUID(), name: "Soohyeok Choi",avatarURL: nil, emoji: "🫐", percent: 76),
        ]
        vm.highlights = []
        return vm
    }

    func load() async {
        guard let client else {
            errorMessage = "Supabase client is not initialized."
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.auth.session
            let currentUserId = session.user.id

            async let challengeRows: [ChallengeData] = client
                .from("challenges")
                .select("*")
                .eq("id", value: challengeId.uuidString)
                .limit(1)
                .execute()
                .value

            async let memberRows: [ChallengeMemberData] = client
                .from("challenge_members")
                .select("*")
                .eq("challenge_id", value: challengeId.uuidString)
                .execute()
                .value

            async let taskRows: [ChallengeTaskData] = client
                .from("challenge_task")
                .select("*")
                .eq("challenge_id", value: challengeId.uuidString)
                .execute()
                .value

            async let completionRows: [ChallengeTaskCompletionData] = client
                .from("challenge_task_completion")
                .select("*")
                .eq("challenge_id", value: challengeId.uuidString)
                .execute()
                .value

            guard let challenge = try await challengeRows.first else {
                errorMessage = "Challenge not found."
                return
            }
            let members = try await memberRows
            let tasks = try await taskRows
            let completions = try await completionRows

            let activeMembers = members.filter { $0.left_at == nil }

            let profiles = await fetchProfiles(client: client, userIds: activeMembers.map(\.user_id))
            let proofs = await fetchProofs(client: client)

            let startDate = dateFromPostgreSQL(challenge.start_date)
            let endDate = dateFromPostgreSQL(challenge.end_date)
            let totalDaysComputed = computeTotalDays(start: startDate, end: endDate)

            title = challenge.title
            dateRangeText = formattedDateRange(start: startDate, end: endDate)
            participantsCount = activeMembers.count
            totalDays = totalDaysComputed

            let validTaskIds = Set(tasks.map { $0.task_id })
            let normalized = dedupCompletions(completions)

            // Scheduled dates within the full challenge window — used as
            // the per-user target denominator. No clamp-to-today: result
            // view shows the final tally for an already-ended challenge.
            let scheduledDates = scheduledDateStrings(
                start: startDate,
                end: endDate,
                repeatType: challenge.repeat_type,
                weeklyDays: challenge.weekly_days,
                monthlyDays: challenge.monthly_days,
                clampToToday: false
            )
            let perUserTarget = max(1, tasks.count * max(scheduledDates.count, 1))

            // Per-user completed = is_completed rows whose task still
            // exists and whose date falls inside [start, end] (string
            // compare works because dates are "yyyy-MM-dd").
            let startStr = startDate.map { formattedDate($0) }
            let endStr = endDate.map { formattedDate($0) }
            var completedByUser: [UUID: Int] = [:]
            for row in normalized where row.isCompleted && validTaskIds.contains(row.taskId) {
                if let s = startStr, row.date < s { continue }
                if let e = endStr, row.date > e { continue }
                completedByUser[row.userId, default: 0] += 1
            }

            // Overall percent across the whole team
            let totalTarget = perUserTarget * max(activeMembers.count, 1)
            let totalCompleted = completedByUser.values.reduce(0, +)
            overallPercent = totalTarget > 0
                ? Int((Double(totalCompleted) / Double(totalTarget)) * 100.0)
                : 0

            // My personal percent + emoji — current user's completions
            // within the challenge window divided by their personal target.
            let myCompleted = completedByUser[currentUserId] ?? 0
            myPercent = perUserTarget > 0
                ? Int((Double(myCompleted) / Double(perUserTarget)) * 100.0)
                : 0
            if let mine = activeMembers.first(where: { $0.user_id == currentUserId }),
               let emoji = mine.member_emoji, !emoji.isEmpty {
                myEmoji = emoji
            }
            print("[ChallengeResult] challenge=\(challengeId) myCompleted=\(myCompleted) perUserTarget=\(perUserTarget) myPercent=\(myPercent) overallPercent=\(overallPercent) range=\(startStr ?? "nil")..\(endStr ?? "nil") scheduledDays=\(scheduledDates.count)")

            // Jar = LAST DAY's state — every member's completion on
            // end_date contributes one of their emojis to the jar.
            jarItems = buildLastDayJarItems(
                completions: normalized,
                activeMembers: activeMembers,
                endDate: endDate
            )
            // Lid: hardcoded green gradient (ChallengeJarView style),
            // sealed when every active member completed every task on
            // end_date — same "all green" condition the detail view uses
            // for today, applied to the challenge's last day.
            lidColorStart = nil
            lidColorEnd = nil
            if let endStr {
                let lastDayCompleted = normalized.filter { $0.isCompleted && $0.date == endStr && validTaskIds.contains($0.taskId) }.count
                let lastDayRequired = activeMembers.count * tasks.count
                isSealed = lastDayRequired > 0 && lastDayCompleted >= lastDayRequired
                print("[ChallengeResult] lastDay=\(endStr) completed=\(lastDayCompleted)/\(lastDayRequired) sealed=\(isSealed) jarItems=\(jarItems.count)")
            } else {
                isSealed = false
            }

            // Dream team: top 5 by personal percent
            dreamTeam = activeMembers
                .map { member -> ChallengeResultParticipantUI in
                    let profile = profiles[member.user_id]
                    let completed = completedByUser[member.user_id] ?? 0
                    let percent = Int((Double(completed) / Double(perUserTarget)) * 100.0)
                    let name = (profile?.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                        ? (profile?.name ?? "Unknown")
                        : "Unknown"
                    let emoji = (member.member_emoji?.isEmpty == false) ? (member.member_emoji ?? "🙂") : "🙂"
                    return ChallengeResultParticipantUI(
                        id: member.user_id,
                        name: name,
                        avatarURL: profile?.avatar_url,
                        emoji: emoji,
                        percent: percent
                    )
                }
                .sorted { $0.percent > $1.percent }
                .prefix(5)
                .map { $0 }

            // Highlights: latest 3 proof photos
            highlights = proofs
                .sorted { (parseISO($0.created_at) ?? .distantPast) > (parseISO($1.created_at) ?? .distantPast) }
                .prefix(3)
                .map { ChallengeGalleryItemUI(id: $0.id, imageURL: $0.proof_url, createdAt: parseISO($0.created_at) ?? .distantPast) }
        } catch {
            errorMessage = "Failed to load result: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private struct NormalizedRow {
        let taskId: UUID
        let userId: UUID
        let date: String
        let isCompleted: Bool
    }

    private func dedupCompletions(_ rows: [ChallengeTaskCompletionData]) -> [NormalizedRow] {
        var dedup: [String: NormalizedRow] = [:]
        for row in rows {
            guard let taskId = row.task_id, let userId = row.user_id, let date = row.date else { continue }
            let key = "\(taskId.uuidString)|\(userId.uuidString)|\(date)"
            dedup[key] = NormalizedRow(taskId: taskId, userId: userId, date: date, isCompleted: row.is_completed ?? false)
        }
        return Array(dedup.values)
    }

    private func computeTotalDays(start: Date?, end: Date?) -> Int {
        guard let start, let end else { return 1 }
        let cal = Calendar.current
        let s = cal.startOfDay(for: min(start, end))
        let e = cal.startOfDay(for: max(start, end))
        return max(1, (cal.dateComponents([.day], from: s, to: e).day ?? 0) + 1)
    }

    private func formattedDateRange(start: Date?, end: Date?) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        let s = start.map { f.string(from: $0) } ?? "--/--"
        let e = end.map { f.string(from: $0) } ?? "--/--"
        return "\(s) - \(e)"
    }

    private func parseISO(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private func fetchProfiles(client: SupabaseClient, userIds: [UUID]) async -> [UUID: ProfileData] {
        guard !userIds.isEmpty else { return [:] }
        do {
            let profiles: [ProfileData] = try await client
                .from("profiles")
                .select("id, name, avatar_url")
                .in("id", value: userIds.map { $0.uuidString })
                .execute()
                .value
            var map: [UUID: ProfileData] = [:]
            for p in profiles { map[p.id] = p }
            return map
        } catch {
            return [:]
        }
    }

    private func buildLastDayJarItems(
        completions: [NormalizedRow],
        activeMembers: [ChallengeMemberData],
        endDate: Date?
    ) -> [JarItemUI] {
        guard let endDate else { return [] }
        let endStr = formattedDate(endDate)
        let activeUserIds = Set(activeMembers.map(\.user_id))
        let emojiByUser: [UUID: String] = Dictionary(
            uniqueKeysWithValues: activeMembers.map { member in
                let emoji = (member.member_emoji?.isEmpty == false) ? (member.member_emoji ?? "🙂") : "🙂"
                return (member.user_id, emoji)
            }
        )

        // Count each member's completed tasks on the last day, then repeat
        // their emoji that many times — same shape as the detail view's
        // jar, but scoped to date == end_date.
        var countsByUser: [UUID: Int] = [:]
        for row in completions where row.isCompleted && row.date == endStr {
            guard activeUserIds.contains(row.userId) else { continue }
            countsByUser[row.userId, default: 0] += 1
        }

        var result: [JarItemUI] = []
        for member in activeMembers.sorted(by: { $0.user_id.uuidString < $1.user_id.uuidString }) {
            let count = countsByUser[member.user_id] ?? 0
            guard count > 0 else { continue }
            let emoji = emojiByUser[member.user_id] ?? "🙂"
            for _ in 0..<count {
                result.append(JarItemUI(id: UUID(), emoji: emoji))
            }
        }
        return result
    }

    private func fetchLatestShakerOnOrBefore(date: Date, client: SupabaseClient) async -> ChallengeShakerData? {
        let upper = formattedDate(date)
        do {
            let rows: [ChallengeShakerData] = try await client
                .from("challenge_shaker")
                .select("*")
                .eq("challenge_id", value: challengeId.uuidString)
                .lte("date", value: upper)
                .order("date", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            return nil
        }
    }

    /// Returns "yyyy-MM-dd" strings for every day the challenge is scheduled,
    /// honoring repeat_type / weekly_days / monthly_days. When clampToToday is
    /// true, dates strictly after today are dropped (so percentages reflect
    /// "of what should have been done so far").
    private func scheduledDateStrings(
        start: Date?,
        end: Date?,
        repeatType: String,
        weeklyDays: [Int]?,
        monthlyDays: [Int]?,
        clampToToday: Bool
    ) -> Set<String> {
        guard let start, let end else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let lower = cal.startOfDay(for: min(start, end))
        var upper = cal.startOfDay(for: max(start, end))
        if clampToToday, upper > today { upper = today }
        if upper < lower { return [] }

        var result = Set<String>()
        var d = lower
        while d <= upper {
            // Calendar.weekday: 1=Sun..7=Sat → app uses 0=Sun..6=Sat
            let weekday = cal.component(.weekday, from: d) - 1
            let dayOfMonth = cal.component(.day, from: d)
            let include: Bool
            switch repeatType {
            case "weekly":
                include = weeklyDays?.contains(weekday) ?? false
            case "monthly":
                include = monthlyDays?.contains(dayOfMonth) ?? false
            default: // "everyday", "daily", or unknown
                include = true
            }
            if include {
                result.insert(formattedDate(d))
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return result
    }

    private func fetchProofs(client: SupabaseClient) async -> [ChallengeTaskProofPhotoData] {
        do {
            let rows: [ChallengeTaskProofPhotoData] = try await client
                .from("challenge_proof_photo")
                .select("*")
                .eq("challenge_id", value: challengeId.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            return rows
        } catch {
            return []
        }
    }
}

// MARK: - Result Jar (preview-style: settled, no motion)

struct ChallengeResultJarView: View {
    let jarItems: [JarItemUI]
    let lidColorStart: String?
    let lidColorEnd: String?
    let isSealed: Bool

    @State private var scene = ShakerScene(size: .zero)
    @State private var lidColors: [Color] = [.black, .gray]
    @State private var lidOpacity: Double = 0
    @State private var didConfigure = false

    private let lidHeightRatio:   CGFloat = 46.0 / 270.0
    private let lidCornerRatio:   CGFloat = 13.0 / 270.0
    private let lidTopInsetRatio: CGFloat = 23.5 / 270.0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let jarSize = CGSize(width: side, height: side)

            ZStack {
                Image("jarBase")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(
                        LinearGradient(colors: lidColors,
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .frame(width: jarSize.width,
                           height: jarSize.height * lidHeightRatio)
                    .cornerRadius(jarSize.height * lidCornerRatio)
                    .offset(y: -jarSize.height / 2 + jarSize.height * lidTopInsetRatio)
                    .opacity(lidOpacity)
                    .allowsHitTesting(false)

                SpriteView(scene: scene, options: [.allowsTransparency])
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)

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
                scene.setEmojiScale(24.0 / 54.0)
                scene.setMotionEnabled(false)
                scene.configureBoundaries(inset: 12, lidHeight: 40, bottomExtraDepth: 10)
                scene.useConstantGravity(18)
                scene.setHapticsEnabled(false)
                syncEmojis()
                applyLid()
                didConfigure = true
            }
            .onChange(of: jarItems.map { "\($0.id.uuidString):\($0.emoji)" }.joined(separator: ",")) { _ in
                guard didConfigure else { return }
                syncEmojis()
            }
            .onChange(of: isSealed) { _ in applyLid() }
            .onChange(of: lidColorStart) { _ in applyLid() }
            .onChange(of: lidColorEnd) { _ in applyLid() }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func syncEmojis() {
        scene.resetScene()
        for item in jarItems {
            scene.addEmoji(item.emoji, for: item.id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scene.settleAllToBottom()
        }
    }

    private func applyLid() {
        // Hardcoded green gradient to match ChallengeJarView in the detail
        // view. lidColorStart/End are still accepted for backwards-compat
        // but ignored.
        lidColors = [AppColors.green300, AppColors.green300.opacity(0.7)]
        // Hide the lid color when the shaker has no emojis — empty jar
        // shouldn't look sealed.
        lidOpacity = jarItems.isEmpty ? 0 : 1
    }
}

// MARK: - Dome Shape

/// A shape with a smooth dome (quadratic-bezier arc) across the top edge
/// and a straight bottom + sides. Used to create the curved section
/// header on the result view.
struct DomeShape: Shape {
    /// Vertical distance from the side (where the arc meets the edge)
    /// down to the apex of the dome at the horizontal center.
    var arcHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Side edges start at arcHeight below the top so the curve has
        // room to peak at rect.minY in the middle.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arcHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + arcHeight),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Static Jar (no SpriteKit, used for ImageRenderer / share card)

/// Image-only jar view used wherever SpriteKit can't render — most
/// importantly inside `ImageRenderer`, which produces a broken-asset
/// placeholder for `SpriteView`. Lays the emojis out in a simple
/// wrapping arrangement so the snapshot still reads as a "jar".
struct ChallengeResultStaticJarView: View {
    let jarItems: [JarItemUI]
    let isSealed: Bool

    private let lidHeightRatio:   CGFloat = 46.0 / 270.0
    private let lidCornerRatio:   CGFloat = 13.0 / 270.0
    private let lidTopInsetRatio: CGFloat = 23.5 / 270.0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Image("jarBase")
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)

                if !jarItems.isEmpty {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.green300, AppColors.green300.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: side, height: side * lidHeightRatio)
                        .cornerRadius(side * lidCornerRatio)
                        .offset(y: -side / 2 + side * lidTopInsetRatio)
                }

                emojiPile(side: side)

                Image("glitchLid")
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func emojiPile(side: CGFloat) -> some View {
        if !jarItems.isEmpty {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 5)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(jarItems) { item in
                    Text(item.emoji)
                        .font(.system(size: side * 0.085))
                }
            }
            .frame(width: side * 0.7, height: side * 0.5, alignment: .bottom)
            .offset(y: side * 0.18)
        }
    }
}

// MARK: - Result View

struct ChallengeResultView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChallengeResultViewModel
    @State private var showShareCard = false
    @State private var showAllParticipants = false

    init(challengeId: UUID) {
        _viewModel = StateObject(wrappedValue: ChallengeResultViewModel(challengeId: challengeId))
    }

    init(viewModel: ChallengeResultViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.textWhite))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Top group — transparent over neutral1000
                        VStack(spacing: 28) {
                            headerSection

                            titleSection
                                .padding(.top, -8)

                            ChallengeResultJarView(
                                jarItems: viewModel.jarItems,
                                lidColorStart: viewModel.lidColorStart,
                                lidColorEnd: viewModel.lidColorEnd,
                                isSealed: viewModel.isSealed
                            )
                            .frame(height: 320)

                            statsRow
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                        // Dome section — #181818 with rounded top corners,
                        // extends to the bottom of the screen.
                        VStack(spacing: 28) {
                            dreamTeamSection
                            highlightsSection
                                .padding(.top, 5)
                            shareButton
                                .padding(.top, 4)
                        }
                        .padding(.top, 52)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 60)
                        .frame(maxWidth: .infinity)
                        .background(
                            DomeShape(arcHeight: 18)
                                .fill(Color(hex: "181818") ?? Color.black)
                        )
                    }
                }
                .ignoresSafeArea(.all, edges: .bottom)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .fullScreenCover(isPresented: $showShareCard) {
            ChallengeShareCardView(
                title: viewModel.title,
                dateRangeText: viewModel.dateRangeText,
                participantsCount: viewModel.participantsCount,
                myPercent: viewModel.myPercent,
                myEmoji: viewModel.myEmoji,
                jarItems: viewModel.jarItems,
                lidColorStart: viewModel.lidColorStart,
                lidColorEnd: viewModel.lidColorEnd,
                isSealed: viewModel.isSealed
            )
        }
    }

    private var headerSection: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(AppColors.neutral400)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
    }

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.dateRangeText)
                .foregroundColor(AppColors.neutral1000)
                .appText(AppFont.labelS)
                .padding(.horizontal, 12)
                .frame(height: 22)
                .background(AppColors.green300)
                .cornerRadius(999)

            Text(viewModel.title)
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.title1)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Text(viewModel.subtitle)
                .foregroundColor(AppColors.neutral300)
                .appText(AppFont.body1)
        }
        .frame(maxWidth: .infinity)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(viewModel.participantsCount)", label: "PARTICIPANTS")
            Rectangle().fill(AppColors.neutral800).frame(width: 1, height: 67)
            statCell(value: "\(viewModel.totalDays)", label: "DAYS")
            Rectangle().fill(AppColors.neutral800).frame(width: 1, height: 67)
            statCell(value: "\(viewModel.overallPercent)%", label: "COMPLETED")
        }
        .padding(.vertical, 8)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.labelL)
            Text(label)
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.captionXS)
        }
        .frame(maxWidth: .infinity)
    }

    private var dreamTeamSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("The Dream Team")
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.labelM)
                Text("\(viewModel.dreamTeam.count)")
                    .foregroundColor(AppColors.green300)
                    .appText(AppFont.labelM)
                Spacer()
                if viewModel.dreamTeam.count > 3 {
                    Button {
                        showAllParticipants.toggle()
                    } label: {
                        Text(showAllParticipants ? "Show less" : "View all")
                            .appText(AppFont.buttonM)
                            .foregroundColor(AppColors.green300)
                    }
                    .buttonStyle(.plain)
                }
            }

            let shown = showAllParticipants ? viewModel.dreamTeam : Array(viewModel.dreamTeam.prefix(3))
            ForEach(Array(shown.enumerated()), id: \.element.id) { idx, p in
                dreamTeamRow(rank: idx + 1, p: p, showCrown: idx == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dreamTeamRow(rank: Int, p: ChallengeResultParticipantUI, showCrown: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .foregroundColor(AppColors.neutral300)
                .appText(AppFont.labelM)
                .frame(width: 16)

            ZStack(alignment: .bottomTrailing) {
                AvatarView(imageURLOrName: p.avatarURL, size: 40)
                Text(p.emoji)
                    .font(.system(size: 12))
                    .padding(3)
                    .background(Circle().fill(AppColors.neutral900))
                    .offset(x: 2, y: 2)
            }

            HStack(spacing: 6) {
                Text(p.name)
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.captionM)
                if showCrown {
                    Image("challengeCrown")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 10)
                }
            }

            Spacer()

            Text("\(p.percent)%")
                .foregroundColor(AppColors.neutral300)
                .appText(AppFont.labelL)
        }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlights")
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.labelM)

            if viewModel.highlights.isEmpty {
                Text("No highlights yet.")
                    .foregroundColor(AppColors.neutral400)
                    .appText(AppFont.captionM)
            } else {
                HStack(spacing: 6) {
                    ForEach(viewModel.highlights) { item in
                        AsyncImage(url: URL(string: item.imageURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                RoundedRectangle(cornerRadius: 8).fill(AppColors.neutral900)
                            }
                        }
                        .frame(width: 114, height: 114)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shareButton: some View {
        Button {
            showShareCard = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera")
                    .font(.system(size: 16, weight: .semibold))
                Text("Share Result")
                    .appText(AppFont.buttonL)
            }
            .foregroundColor(AppColors.neutral1000)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.green300)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Card

struct ChallengeShareCardView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let dateRangeText: String
    let participantsCount: Int
    let myPercent: Int
    let myEmoji: String
    let jarItems: [JarItemUI]
    let lidColorStart: String?
    let lidColorEnd: String?
    let isSealed: Bool

    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            // Blurred + dimmed background showing the result view behind
            DarkBlurView(style: .systemThinMaterialDark)
                .ignoresSafeArea()
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(AppColors.neutral400)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Text("Save or share your challenge\nresult card with friends.")
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.title3)
                    .multilineTextAlignment(.center)

                cardContent
                    .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    actionButton(systemName: "arrow.down.to.line", title: "Save") {
                        saveToPhotos()
                    }
                    actionButton(systemName: "arrowshape.turn.up.right", title: "Share") {
                        share()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                Spacer()
            }
        }
        .presentationBackground(.clear)
        .sheet(isPresented: $showShareSheet) {
            if let renderedImage {
                ShareSheet(items: [renderedImage])
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 16) {
            Image("clink")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 22)
                .foregroundColor(AppColors.textWhite)
                .padding(.top, 18)

            ChallengeResultStaticJarView(
                jarItems: jarItems,
                isSealed: isSealed
            )
            .frame(height: 240)

            Text(title)
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.title2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            HStack(spacing: 0) {
                cardStat(value: "\(participantsCount)", label: "PARTICIPANTS")
                Rectangle().fill(AppColors.neutral800).frame(width: 1, height: 67)
                cardStat(value: dateRangeText, label: "PERIOD")
                Rectangle().fill(AppColors.neutral800).frame(width: 1, height: 67)
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("\(myPercent)%")
                            .foregroundColor(AppColors.textWhite)
                            .appText(AppFont.labelL)
                        Text(myEmoji)
                            .font(.system(size: 14))
                    }
                    Text("COMPLETED")
                        .foregroundColor(AppColors.textWhite)
                        .appText(AppFont.captionXS)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: AppColors.neutral800, location: 0.0),
                            .init(color: AppColors.neutral900, location: 0.15),
                            .init(color: AppColors.neutral1000, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color("Neutral-400").opacity(0.5),
                            Color("Neutral-600").opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func cardStat(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.labelL)
            Text(label)
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.captionXS)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(systemName: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .appText(AppFont.buttonL)
            }
            .foregroundColor(AppColors.neutral1000)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func renderCard() -> UIImage? {
        let renderer = ImageRenderer(content:
            cardContent
                .frame(width: 320)
                .padding(16)
                .background(AppColors.neutral1000)
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    private func saveToPhotos() {
        guard let image = renderCard() else { return }
        renderedImage = image
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    private func share() {
        guard let image = renderCard() else { return }
        renderedImage = image
        showShareSheet = true
    }
}

// MARK: - Share Sheet

