import Foundation
import SwiftUI
import Supabase
import UIKit

struct WeeklyDayUI: Identifiable {
    let id = UUID()
    let weekday: String
    let day: String
    let isChallengeDay: Bool
    let isCompleted: Bool
    let lidColorStart: String?
    let lidColorEnd: String?
    let isToday: Bool
}

struct JarItemUI: Identifiable {
    let id: UUID
    let emoji: String
}

struct TodayTaskUI: Identifiable {
    let id: UUID
    let title: String
    var isCompleted: Bool
    var hasProof: Bool
    var proofURL: String?
}

struct ChallengeParticipantUI: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let joinedDays: Int
    let isOwner: Bool
}

struct ChallengeGalleryItemUI: Identifiable {
    let id: UUID
    let imageURL: String
    let createdAt: Date
    let uploaderUserId: UUID
    let uploaderName: String
    let uploaderAvatarURL: String?
}

struct ChallengeCommentUI: Identifiable {
    let id: Int64
    let commenterId: UUID
    let commenterName: String
    let commenterAvatarURL: String?
    let comment: String
    let createdAt: Date
    let relativeTimeText: String
}

struct ChallengeTaskProofPhotoData: Codable, Identifiable {
    let id: UUID
    let challenge_id: UUID
    let task_id: UUID
    let uploader_user_id: UUID
    let proof_date: String
    let storage_path: String
    let proof_url: String
    let created_at: String?
}

struct ChallengeCommentData: Codable, Identifiable {
    let id: Int64
    let created_at: String?
    let challenge_id: UUID
    let commenter_id: UUID?
    let comment: String?
}

@MainActor
final class ChallengeDetailViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isSubmittingDay = false
    @Published var isUploadingProof = false
    @Published var errorMessage: String?

    @Published var title = ""
    @Published var description = ""
    @Published var dateRangeText = ""
    @Published var dayIndexText = "Day 0 of 0"

    @Published var overallProgress: Double = 0
    @Published var overallProgressText = "0 / 0"

    @Published var weekly: [WeeklyDayUI] = []
    @Published var jarItems: [JarItemUI] = []
    @Published var todayJarItemsForLid: [JarItemUI] = []
    @Published var todayLidColorStart: String?
    @Published var todayLidColorEnd: String?
    @Published var isTodaySealed: Bool = false
    @Published var todayShakerIsCompleted: Bool = false
    @Published var todayTasks: [TodayTaskUI] = []
    @Published var participants: [ChallengeParticipantUI] = []
    @Published var galleryItems: [ChallengeGalleryItemUI] = []
    @Published var communityComments: [ChallengeCommentUI] = []
    @Published var commentDraft: String = ""
    @Published var isSendingComment = false
    @Published var currentUserAvatarURL: String?
    @Published var isPhotoProofEnabled = true
    @Published var isPhotoProofRequired = false

    @Published var isFavorite = false

    let challengeId: UUID

    private let client = SupabaseClientManager.shared.client
    private var currentUserId: UUID?

    private var challenge: ChallengeData?
    private var members: [ChallengeMemberData] = []
    private var tasks: [ChallengeTaskData] = []
    private var completions: [ChallengeTaskCompletionData] = []
    private var proofPhotos: [ChallengeTaskProofPhotoData] = []
    private var comments: [ChallengeCommentData] = []
    private var profilesByUserId: [UUID: ProfileData] = [:]
    private var persistedTodayCompletionByTask: [UUID: Bool] = [:]
    private var todayChallengeShakerRow: ChallengeShakerRow?
    private var challengeShakerByDate: [String: ChallengeShakerRow] = [:]

    init(challengeId: UUID) {
        self.challengeId = challengeId
    }

    func load() async {
        await fetchAll(showLoading: true)
    }

    func refreshAfterMutation() async {
        await fetchAll(showLoading: false)
    }

    func toggleFavorite() {
        let targetValue = !isFavorite
        isFavorite = targetValue

        Task {
            await persistFavorite(targetValue)
        }
    }

    private func persistFavorite(_ favorite: Bool) async {
        guard let client, let userId = currentUserId else { return }

        do {
            try await client
                .from("challenge_members")
                .update(["favorite": favorite])
                .eq("challenge_id", value: challengeId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
        } catch {
            isFavorite = !favorite
            errorMessage = "Failed to update favorite: \(error.localizedDescription)"
        }
    }

    func toggleTask(taskId: UUID) {
        guard isTaskToggleAllowed(on: Date()) else { return }
        guard let idx = todayTasks.firstIndex(where: { $0.id == taskId }) else { return }
        guard canToggleTaskCompletion(todayTasks[idx]) else { return }
        todayTasks[idx].isCompleted.toggle()
    }

    func canToggleTaskCompletion(_ task: TodayTaskUI) -> Bool {
        !isPhotoProofRequired || task.hasProof
    }

    func uploadProofImage(taskId: UUID, image: UIImage) async -> Bool {
        guard let client, let userId = currentUserId else { return false }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process selected image."
            return false
        }

        isUploadingProof = true
        defer { isUploadingProof = false }

        let today = formattedDate(Date())
        let uid = userId.uuidString.lowercased()
        let cid = challengeId.uuidString.lowercased()
        let tid = taskId.uuidString.lowercased()

        do {
            struct ProofInsertPayload: Encodable {
                let challenge_id: UUID
                let task_id: UUID
                let uploader_user_id: UUID
                let proof_date: String
                let storage_path: String
                let proof_url: String
            }

            struct ExistingProofRow: Decodable {
                let id: UUID
                let storage_path: String?
            }
            let existingRows: [ExistingProofRow] = try await client
                .from("challenge_proof_photo")
                .select("id, storage_path")
                .eq("challenge_id", value: challengeId.uuidString)
                .eq("task_id", value: taskId.uuidString)
                .eq("uploader_user_id", value: userId.uuidString)
                .eq("proof_date", value: today)
                .limit(1)
                .execute()
                .value
            
            // Use unique path per update to avoid stale image caching by same URL.
            let filePath = "\(uid)/\(cid)/\(tid)/\(today)/\(UUID().uuidString.lowercased()).jpg"
            
            do {
                try await client.storage
                    .from("challenge-proofs")
                    .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: false))
            } catch {
                errorMessage = "Proof upload failed (storage RLS/policy): \(error.localizedDescription)"
                return false
            }
            
            guard let proofURL = try? client.storage
                .from("challenge-proofs")
                .getPublicURL(path: filePath).absoluteString else {
                errorMessage = "Failed to get proof image URL."
                return false
            }

            if let existing = existingRows.first {
                let oldPath = existing.storage_path
                try await client
                    .from("challenge_proof_photo")
                    .update([
                        "storage_path": filePath,
                        "proof_url": proofURL
                    ])
                    .eq("id", value: existing.id.uuidString)
                    .execute()
                
                // best-effort cleanup of previous image file
                if let oldPath, !oldPath.isEmpty, oldPath != filePath {
                    _ = try? await client.storage
                        .from("challenge-proofs")
                        .remove(paths: [oldPath])
                }
            } else {
                let payload = ProofInsertPayload(
                    challenge_id: challengeId,
                    task_id: taskId,
                    uploader_user_id: userId,
                    proof_date: today,
                    storage_path: filePath,
                    proof_url: proofURL
                )

                try await client
                    .from("challenge_proof_photo")
                    .insert(payload)
                    .execute()
            }

            await applyProofUploadLocally(client: client, completedTaskId: taskId)
            return true
        } catch {
            errorMessage = "Proof metadata save failed (table RLS/policy): \(error.localizedDescription)"
            return false
        }
    }

    private func applyProofUploadLocally(client: SupabaseClient, completedTaskId: UUID) async {
        let pendingCompletionByTask = Dictionary(
            uniqueKeysWithValues: todayTasks.map { ($0.id, $0.isCompleted) }
        )

        proofPhotos = await fetchProofRowsSafely(client: client)
        buildUI()

        for idx in todayTasks.indices {
            let taskId = todayTasks[idx].id
            todayTasks[idx].isCompleted = pendingCompletionByTask[taskId] ?? todayTasks[idx].isCompleted
        }

        if let idx = todayTasks.firstIndex(where: { $0.id == completedTaskId }) {
            todayTasks[idx].isCompleted = true
        }
    }

    var hasPendingTaskChanges: Bool {
        for task in todayTasks {
            let persisted = persistedTodayCompletionByTask[task.id] ?? false
            if persisted != task.isCompleted { return true }
        }
        return false
    }

    var isCompleteDayButtonEnabled: Bool {
        hasPendingTaskChanges && !isSubmittingDay
    }

    func submitTodayChallenge() async {
        guard let client, let userId = currentUserId, isCompleteDayButtonEnabled else { return }
        isSubmittingDay = true

        do {
            let today = formattedDate(Date())

            struct ExistingCompletionRow: Decodable {
                let id: UUID
                let task_id: UUID
            }

            struct InsertCompletion: Encodable {
                let challenge_id: UUID
                let task_id: UUID
                let user_id: UUID
                let date: String
                let is_completed: Bool
            }

            let existingRows: [ExistingCompletionRow] = try await client
                .from("challenge_task_completion")
                .select("id, task_id")
                .eq("challenge_id", value: challengeId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .eq("date", value: today)
                .execute()
                .value

            let existingByTask = Dictionary(uniqueKeysWithValues: existingRows.map { ($0.task_id, $0.id) })

            for task in todayTasks {
                if let existingId = existingByTask[task.id] {
                    try await client
                        .from("challenge_task_completion")
                        .update(["is_completed": task.isCompleted])
                        .eq("id", value: existingId.uuidString)
                        .execute()
                } else {
                    let payload = InsertCompletion(
                        challenge_id: challengeId,
                        task_id: task.id,
                        user_id: userId,
                        date: today,
                        is_completed: task.isCompleted
                    )
                    try await client
                        .from("challenge_task_completion")
                        .insert(payload)
                        .execute()
                }
            }
            // Optimistic local update for immediate jar/progress refresh.
            applyTodayCompletionOptimistically(userId: userId, date: today)
            buildUI()

            // Ensure today's challenge_shaker row exists right after submit.
            // If completed, keep lid colors only when available; otherwise persist nulls.
            await ensureTodayShakerRowExistsAfterSubmit(client: client, date: today)
            isSubmittingDay = false

            // Keep server truth in sync without blocking UI responsiveness.
            Task { [weak self] in
                guard let self else { return }
                await self.refreshAfterMutation()
            }
        } catch {
            isSubmittingDay = false
            errorMessage = "Failed to save today's challenge: \(error.localizedDescription)"
        }
    }

    private func ensureTodayShakerRowExistsAfterSubmit(client: SupabaseClient, date: String) async {
        // If row already exists for today, no insert is needed.
        guard challengeShakerByDate[date] == nil else { return }

        let state = computeDailyShakerState(for: date)
        let lidPair = resolvedLidHexPairForSubmit(date: date, state: state)
        let lidStart = state.isCompleted ? lidPair.0 : nil
        let lidEnd = state.isCompleted ? lidPair.1 : nil

        do {
            try await saveTodayChallengeShaker(
                client: client,
                date: date,
                state: state,
                lidColorStart: lidStart,
                lidColorEnd: lidEnd
            )

            if let loaded = await fetchTodayChallengeShakerSafely(client: client, today: date) {
                challengeShakerByDate[date] = loaded
                if date == formattedDate(Date()) {
                    todayChallengeShakerRow = loaded
                    todayLidColorStart = loaded.lid_color_start
                    todayLidColorEnd = loaded.lid_color_end
                    todayShakerIsCompleted = loaded.iscompleted
                }
            }
        } catch {
            print("[ChallengeShakerSync] ensure row after submit failed: \(error)")
        }
    }

    private func resolvedLidHexPairForSubmit(
        date: String,
        state: DailyShakerState
    ) -> (String, String) {
        if let start = todayLidColorStart,
           let end = todayLidColorEnd,
           UIColor(hex: start) != nil,
           UIColor(hex: end) != nil {
            return (start, end)
        }

        if let extracted = extractLidHexPairFromRenderedEmojis(state.userEmojis) {
            return extracted
        }

        return deterministicLidHexPair(date: date, emojis: state.userEmojis)
    }

    private func extractLidHexPairFromRenderedEmojis(_ emojis: [String]) -> (String, String)? {
        guard !emojis.isEmpty else { return nil }

        let dim = 40
        let bytesPerRow = dim * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let font = UIFont(name: "AppleColorEmoji", size: 34) ?? UIFont.systemFont(ofSize: 34)
        var hist: [UInt32: Int] = [:]

        for emoji in emojis {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: dim, height: dim))
            let image = renderer.image { ctx in
                UIColor.clear.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: dim, height: dim))

                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                let ns = emoji as NSString
                let textSize = ns.size(withAttributes: attrs)
                let rect = CGRect(
                    x: (CGFloat(dim) - textSize.width) / 2,
                    y: (CGFloat(dim) - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                ns.draw(in: rect, withAttributes: attrs)
            }

            guard let cg = image.cgImage,
                  let ctx = CGContext(
                      data: nil,
                      width: dim,
                      height: dim,
                      bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow,
                      space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else { continue }

            ctx.interpolationQuality = .none
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: dim, height: dim))
            guard let data = ctx.data else { continue }
            let px = data.bindMemory(to: UInt8.self, capacity: dim * dim * 4)

            for i in stride(from: 0, to: dim * dim, by: 2) {
                let off = i * 4
                let alpha = px[off + 3]
                if alpha < 180 { continue }

                let r = px[off] >> 3
                let g = px[off + 1] >> 3
                let b = px[off + 2] >> 3
                let key = UInt32(r) << 10 | UInt32(g) << 5 | UInt32(b)
                hist[key, default: 0] += 1
            }
        }

        guard !hist.isEmpty else { return nil }

        let sorted = hist.sorted { $0.value > $1.value }
        let palette = sorted.prefix(6).map { quantizedKeyToUIColor($0.key) }
        guard let first = palette.first else { return nil }

        let second = palette.dropFirst().first { rgbDistance(first, $0) >= 0.18 } ?? adjustedPairColor(from: first)
        return (first.toHex(), second.toHex())
    }

    private func quantizedKeyToUIColor(_ key: UInt32) -> UIColor {
        let r = CGFloat(((key >> 10) & 0x1F) << 3) / 255.0
        let g = CGFloat(((key >> 5) & 0x1F) << 3) / 255.0
        let b = CGFloat((key & 0x1F) << 3) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    private func adjustedPairColor(from color: UIColor) -> UIColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return color
        }
        return UIColor(
            hue: h,
            saturation: min(1, max(0, s * 0.95 + 0.05)),
            brightness: min(1, max(0, b * 0.75 + 0.15)),
            alpha: 1
        )
    }

    private func rgbDistance(_ lhs: UIColor, _ rhs: UIColor) -> CGFloat {
        var lr: CGFloat = 0
        var lg: CGFloat = 0
        var lb: CGFloat = 0
        var la: CGFloat = 0
        var rr: CGFloat = 0
        var rg: CGFloat = 0
        var rb: CGFloat = 0
        var ra: CGFloat = 0
        guard lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la),
              rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        else { return 0 }
        let dr = lr - rr
        let dg = lg - rg
        let db = lb - rb
        return sqrt(dr * dr + dg * dg + db * db)
    }

    private func deterministicLidHexPair(date: String, emojis: [String]) -> (String, String) {
        let base = date + "|" + emojis.joined(separator: "|")
        var hash: UInt64 = 1469598103934665603
        for byte in base.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }

        let hue0 = CGFloat(hash % 360) / 360.0
        let offsetDeg = CGFloat((hash / 360) % 120 + 35) / 360.0
        let hue1 = (hue0 + offsetDeg).truncatingRemainder(dividingBy: 1)

        let c0 = UIColor(hue: hue0, saturation: 0.78, brightness: 0.92, alpha: 1)
        let c1 = UIColor(hue: hue1, saturation: 0.72, brightness: 0.86, alpha: 1)
        return (c0.toHex(), c1.toHex())
    }

    func persistTodayShakerBecameSealed(start: String, end: String) async {
        await persistTodayShakerTransition(isCompleted: true, lidStart: start, lidEnd: end)
    }

    func persistTodayShakerBecameUnsealed() async {
        await persistTodayShakerTransition(isCompleted: false, lidStart: nil, lidEnd: nil)
    }

    private func persistTodayShakerTransition(isCompleted: Bool, lidStart: String?, lidEnd: String?) async {
        guard let client else { return }

        let today = formattedDate(Date())
        let currentCompleted = (todayChallengeShakerRow?.date == today) ? (todayChallengeShakerRow?.iscompleted ?? false) : false
        guard currentCompleted != isCompleted else { return }

        let day = computeDailyShakerState(for: today)
        let state = DailyShakerState(isCompleted: isCompleted, userEmojis: day.userEmojis)

        do {
            try await saveTodayChallengeShaker(
                client: client,
                date: today,
                state: state,
                lidColorStart: lidStart,
                lidColorEnd: lidEnd
            )

            if let loaded = await fetchTodayChallengeShakerSafely(client: client, today: today) {
                todayChallengeShakerRow = loaded
                todayLidColorStart = loaded.lid_color_start
                todayLidColorEnd = loaded.lid_color_end
                todayShakerIsCompleted = loaded.iscompleted
            } else {
                todayLidColorStart = lidStart
                todayLidColorEnd = lidEnd
                todayShakerIsCompleted = isCompleted
            }
        } catch {
            print("[ChallengeShakerSync] state transition save failed: \(error)")
        }
    }

    func submitComment() async {
        let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let client, let userId = currentUserId else { return }

        isSendingComment = true
        defer { isSendingComment = false }

        do {
            struct CommentInsertPayload: Encodable {
                let challenge_id: UUID
                let commenter_id: UUID
                let comment: String
            }

            let payload = CommentInsertPayload(
                challenge_id: challengeId,
                commenter_id: userId,
                comment: trimmed
            )

            try await client
                .from("challenge_comment")
                .insert(payload)
                .execute()

            commentDraft = ""
            await refreshAfterMutation()
        } catch {
            errorMessage = "Failed to send comment: \(error.localizedDescription)"
        }
    }

    func isMyComment(_ item: ChallengeCommentUI) -> Bool {
        guard let currentUserId else { return false }
        return item.commenterId == currentUserId
    }

    func deleteComment(commentId: Int64) async {
        guard let client, let userId = currentUserId else { return }
        do {
            try await client
                .from("challenge_comment")
                .delete()
                .eq("id", value: String(commentId))
                .eq("commenter_id", value: userId.uuidString)
                .execute()
            await refreshAfterMutation()
        } catch {
            errorMessage = "Failed to delete comment: \(error.localizedDescription)"
        }
    }

    private func fetchAll(showLoading: Bool) async {
        guard let client else {
            errorMessage = "Supabase client is not initialized."
            return
        }

        if showLoading {
            isLoading = true
        }
        errorMessage = nil

        do {
            let session = try await client.auth.session
            currentUserId = session.user.id

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
                .order("sortorder", ascending: true)
                .execute()
                .value

            async let completionRows: [ChallengeTaskCompletionData] = client
                .from("challenge_task_completion")
                .select("*")
                .eq("challenge_id", value: challengeId.uuidString)
                .execute()
                .value

            async let challengeShakerRows: [ChallengeShakerRow] = fetchChallengeShakerRowsSafely(client: client)
            
            async let commentRows: [ChallengeCommentData] = client
                .from("challenge_comment")
                .select("*")
                .eq("challenge_id", value: challengeId.uuidString)
                .order("created_at", ascending: false)
                .limit(200)
                .execute()
                .value

            let loadedChallengeRows = try await challengeRows
            guard let loadedChallenge = loadedChallengeRows.first else {
                throw NSError(
                    domain: "ChallengeDetail",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Challenge not found"]
                )
            }

            challenge = loadedChallenge
            members = try await memberRows
            isFavorite = members.first {
                $0.user_id == currentUserId && $0.left_at == nil
            }?.favorite ?? false
            tasks = try await taskRows
            completions = try await completionRows
            let loadedShakerRows = await challengeShakerRows
            challengeShakerByDate = Dictionary(uniqueKeysWithValues: loadedShakerRows.map { ($0.date, $0) })
            todayChallengeShakerRow = challengeShakerByDate[formattedDate(Date())]
            comments = (try? await commentRows) ?? []
            proofPhotos = await fetchProofRowsSafely(client: client)
            let commenterIds = comments.compactMap { $0.commenter_id }
            let proofUploaderIds = proofPhotos.map(\.uploader_user_id)
            profilesByUserId = await fetchProfilesMapSafely(
                client: client,
                members: members,
                additionalUserIds: commenterIds + proofUploaderIds
            )

            buildUI()
        } catch {
            errorMessage = "Failed to load challenge detail: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func buildUI() {
        guard let challenge else { return }

        let activeMembers = members.filter { $0.left_at == nil }
        let today = Date()
        let todayString = formattedDate(today)

        let startDate = dateFromPostgreSQL(challenge.start_date)
        let endDate = dateFromPostgreSQL(challenge.end_date)

        title = challenge.title
        let proofType = challenge.proof_type.lowercased()
        isPhotoProofEnabled = proofType != "checklist"
        isPhotoProofRequired = proofType == "photo_upload_required"
        if let rawDescription = challenge.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawDescription.isEmpty {
            description = rawDescription
        } else {
            description = "No challenge description."
        }
        dateRangeText = formattedDateRange(startDate: startDate, endDate: endDate)

        let normalizedCompletions = normalizedCompletionRows(from: completions)
        let currentUserProofByTaskToday = proofByTaskForCurrentUserToday(proofPhotos: proofPhotos, today: todayString)
        let completionDayCountByUser = completionDayCountByUser(normalizedCompletions: normalizedCompletions)

        let myCompletionsToday = Dictionary(
            uniqueKeysWithValues: normalizedCompletions
                .filter { $0.date == todayString && $0.userId == currentUserId }
                .map { ($0.taskId, $0.isCompleted) }
        )

        todayTasks = tasks.map { task in
            return TodayTaskUI(
                id: task.task_id,
                title: task.task_title ?? "Untitled Task",
                isCompleted: myCompletionsToday[task.task_id] ?? false,
                hasProof: currentUserProofByTaskToday[task.task_id] != nil,
                proofURL: currentUserProofByTaskToday[task.task_id]?.proof_url
            )
        }
        persistedTodayCompletionByTask = Dictionary(
            uniqueKeysWithValues: todayTasks.map { ($0.id, $0.isCompleted) }
        )

        participants = activeMembers
            .map { member in
                let profile = profilesByUserId[member.user_id]
                return ChallengeParticipantUI(
                    id: member.user_id,
                    name: profile?.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? (profile?.name ?? "Unknown")
                        : "Unknown",
                    emoji: (member.member_emoji?.isEmpty == false) ? (member.member_emoji ?? "🙂") : "🙂",
                    joinedDays: completionDayCountByUser[member.user_id] ?? 0,
                    isOwner: member.role == "owner"
                )
            }
            .sorted {
                if $0.joinedDays == $1.joinedDays {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.joinedDays > $1.joinedDays
            }

        galleryItems = proofPhotos
            .map { proof in
                let profile = profilesByUserId[proof.uploader_user_id]
                let uploaderName = profile?.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? (profile?.name ?? "Unknown")
                    : "Unknown"

                return ChallengeGalleryItemUI(
                    id: proof.id,
                    imageURL: proof.proof_url,
                    createdAt: parseDateTime(proof.created_at) ?? .distantPast,
                    uploaderUserId: proof.uploader_user_id,
                    uploaderName: uploaderName,
                    uploaderAvatarURL: profile?.avatar_url
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
        
        communityComments = comments
            .compactMap { commentData in
                guard let commenterId = commentData.commenter_id else { return nil }
                let commentText = (commentData.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !commentText.isEmpty else { return nil }

                let profile = profilesByUserId[commenterId]
                let name = profile?.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? (profile?.name ?? "Unknown")
                    : "Unknown"
                let createdAt = parseDateTime(commentData.created_at) ?? Date()

                return ChallengeCommentUI(
                    id: commentData.id,
                    commenterId: commenterId,
                    commenterName: name,
                    commenterAvatarURL: profile?.avatar_url,
                    comment: commentText,
                    createdAt: createdAt,
                    relativeTimeText: relativeTimeString(from: createdAt)
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
        
        if let currentUserId {
            currentUserAvatarURL = profilesByUserId[currentUserId]?.avatar_url
        } else {
            currentUserAvatarURL = nil
        }

        jarItems = buildCumulativeJarItems(
            normalizedCompletions: normalizedCompletions,
            activeMembers: activeMembers,
            startDate: startDate,
            endDate: endDate,
            today: today
        )
        todayJarItemsForLid = buildDailyJarItems(
            normalizedCompletions: normalizedCompletions,
            activeMembers: activeMembers,
            dateString: todayString
        )
        if todayChallengeShakerRow?.date == todayString {
            todayLidColorStart = todayChallengeShakerRow?.lid_color_start
            todayLidColorEnd = todayChallengeShakerRow?.lid_color_end
            todayShakerIsCompleted = todayChallengeShakerRow?.iscompleted ?? false
        } else {
            todayLidColorStart = nil
            todayLidColorEnd = nil
            todayShakerIsCompleted = false
        }

        isTodaySealed = dailyCompletionStatus(
            normalizedCompletions: normalizedCompletions,
            activeMembers: activeMembers,
            dateString: todayString
        ).isAllCompleted

        weekly = buildWeeklyRows(today: today)

        let totalDays = totalChallengeDays(startDate: startDate, endDate: endDate)
        let elapsedDays = elapsedChallengeDays(startDate: startDate, endDate: endDate, today: today)
        dayIndexText = "Day \(elapsedDays) of \(totalDays)"

        let targetTaskCount = activeMembers.count * tasks.count * totalDays
        let allCompletedCount = normalizedCompletions.filter { $0.isCompleted }.count
        overallProgress = targetTaskCount > 0
            ? min(1, Double(allCompletedCount) / Double(targetTaskCount))
            : 0
        overallProgressText = "\(allCompletedCount) / \(targetTaskCount)"
    }

    private func buildWeeklyRows(today: Date) -> [WeeklyDayUI] {
        let calendar = Calendar.current
        let startOfWeek = calendar.startOfWeek(for: today)
        let weekdayLabels = calendar.shortStandaloneWeekdaySymbols.map { $0.uppercased() }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { return nil }
            let dateKey = formattedDate(date)
            let isChallengeDay = isTaskToggleAllowed(on: date)
            let shakerRow = challengeShakerByDate[dateKey]
            let isCompleted = isChallengeDay && (shakerRow?.iscompleted ?? false)

            return WeeklyDayUI(
                weekday: weekdayLabels[offset],
                day: String(calendar.component(.day, from: date)),
                isChallengeDay: isChallengeDay,
                isCompleted: isCompleted,
                lidColorStart: shakerRow?.lid_color_start,
                lidColorEnd: shakerRow?.lid_color_end,
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
    }

    private func formattedDateRange(startDate: Date?, endDate: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        let startText = startDate.map { formatter.string(from: $0) } ?? "--/--"
        let endText = endDate.map { formatter.string(from: $0) } ?? "--/--"
        return "\(startText)-\(endText)"
    }

    private func totalChallengeDays(startDate: Date?, endDate: Date?) -> Int {
        guard let startDate, let endDate else { return 1 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: min(startDate, endDate))
        let end = calendar.startOfDay(for: max(startDate, endDate))
        let delta = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, delta + 1)
    }

    private func elapsedChallengeDays(startDate: Date?, endDate: Date?, today: Date) -> Int {
        guard let startDate, let endDate else { return 1 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: min(startDate, endDate))
        let end = calendar.startOfDay(for: max(startDate, endDate))
        let clampedToday = min(max(calendar.startOfDay(for: today), start), end)
        let delta = calendar.dateComponents([.day], from: start, to: clampedToday).day ?? 0
        return max(1, delta + 1)
    }

    private func normalizedCompletionRows(from rows: [ChallengeTaskCompletionData]) -> [NormalizedCompletion] {
        var dedup: [String: NormalizedCompletion] = [:]

        for row in rows {
            guard let taskId = row.task_id,
                  let userId = row.user_id,
                  let date = row.date else { continue }

            let key = "\(taskId.uuidString)|\(userId.uuidString)|\(date)"
            let value = NormalizedCompletion(
                taskId: taskId,
                userId: userId,
                date: date,
                isCompleted: row.is_completed ?? false
            )
            dedup[key] = value
        }

        return Array(dedup.values)
    }

    private func applyTodayCompletionOptimistically(userId: UUID, date: String) {
        var rows = completions

        // Remove all possibly duplicated rows for today's current user's tasks first.
        let todayTaskIds = Set(todayTasks.map(\.id))
        rows.removeAll {
            guard let taskId = $0.task_id, let rowUserId = $0.user_id, let rowDate = $0.date else { return false }
            return rowUserId == userId && rowDate == date && todayTaskIds.contains(taskId)
        }

        // Rebuild one normalized row per task with current toggle state.
        for task in todayTasks {
            rows.append(
                ChallengeTaskCompletionData(
                    id: UUID(),
                    challenge_id: challengeId,
                    task_id: task.id,
                    user_id: userId,
                    date: date,
                    is_completed: task.isCompleted
                )
            )
        }

        completions = rows
        persistedTodayCompletionByTask = Dictionary(
            uniqueKeysWithValues: todayTasks.map { ($0.id, $0.isCompleted) }
        )
    }

    private struct NormalizedCompletion {
        let taskId: UUID
        let userId: UUID
        let date: String
        let isCompleted: Bool
    }

    private struct DailyShakerState {
        let isCompleted: Bool
        let userEmojis: [String]
    }

    private struct DailyCompletionStatus {
        let requiredCount: Int
        let completedCount: Int

        var isAllCompleted: Bool {
            requiredCount > 0 && completedCount >= requiredCount
        }
    }

    private struct ChallengeShakerRow: Decodable {
        let id: UUID
        let challenge_id: UUID
        let date: String
        let iscompleted: Bool
        let user_emojis: [String]
        let lid_color_start: String?
        let lid_color_end: String?
    }

    private struct ChallengeShakerWritePayload: Encodable {
        let challenge_id: UUID
        let date: String
        let iscompleted: Bool
        let user_emojis: [String]
        let lid_color_start: String?
        let lid_color_end: String?

        enum CodingKeys: String, CodingKey {
            case challenge_id, date, iscompleted, user_emojis, lid_color_start, lid_color_end
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(challenge_id, forKey: .challenge_id)
            try c.encode(date, forKey: .date)
            try c.encode(iscompleted, forKey: .iscompleted)
            try c.encode(user_emojis, forKey: .user_emojis)
            if let lid_color_start {
                try c.encode(lid_color_start, forKey: .lid_color_start)
            } else {
                try c.encodeNil(forKey: .lid_color_start)
            }
            if let lid_color_end {
                try c.encode(lid_color_end, forKey: .lid_color_end)
            } else {
                try c.encodeNil(forKey: .lid_color_end)
            }
        }
    }

    private struct ChallengeShakerUpdatePayload: Encodable {
        let iscompleted: Bool
        let user_emojis: [String]
        let lid_color_start: String?
        let lid_color_end: String?

        enum CodingKeys: String, CodingKey {
            case iscompleted, user_emojis, lid_color_start, lid_color_end
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(iscompleted, forKey: .iscompleted)
            try c.encode(user_emojis, forKey: .user_emojis)
            if let lid_color_start {
                try c.encode(lid_color_start, forKey: .lid_color_start)
            } else {
                try c.encodeNil(forKey: .lid_color_start)
            }
            if let lid_color_end {
                try c.encode(lid_color_end, forKey: .lid_color_end)
            } else {
                try c.encodeNil(forKey: .lid_color_end)
            }
        }
    }

    private struct ChallengeShakerRowId: Decodable {
        let id: UUID
    }

    private func fetchTodayChallengeShakerSafely(
        client: SupabaseClient,
        today: String
    ) async -> ChallengeShakerRow? {
        do {
            let rows: [ChallengeShakerRow] = try await client
                .from("challenge_shaker")
                .select("id, challenge_id, date, iscompleted, user_emojis, lid_color_start, lid_color_end")
                .eq("challenge_id", value: challengeId.uuidString)
                .eq("date", value: today)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            return nil
        }
    }

    private func fetchChallengeShakerRowsSafely(client: SupabaseClient) async -> [ChallengeShakerRow] {
        do {
            let rows: [ChallengeShakerRow] = try await client
                .from("challenge_shaker")
                .select("id, challenge_id, date, iscompleted, user_emojis, lid_color_start, lid_color_end")
                .eq("challenge_id", value: challengeId.uuidString)
                .execute()
                .value
            return rows
        } catch {
            return []
        }
    }

    private func computeDailyShakerState(for dateString: String) -> DailyShakerState {
        let activeMembers = members.filter { $0.left_at == nil }
        let normalized = normalizedCompletionRows(from: completions)
        let day = dailyCompletionStatus(
            normalizedCompletions: normalized,
            activeMembers: activeMembers,
            dateString: dateString
        )

        let dayItems = buildDailyJarItems(
            normalizedCompletions: normalized,
            activeMembers: activeMembers,
            dateString: dateString
        )
        return DailyShakerState(
            isCompleted: day.isAllCompleted,
            userEmojis: dayItems.map(\.emoji)
        )
    }

    private func dailyCompletionStatus(
        normalizedCompletions: [NormalizedCompletion],
        activeMembers: [ChallengeMemberData],
        dateString: String
    ) -> DailyCompletionStatus {
        let activeUserIds = Set(activeMembers.map(\.user_id))
        let taskIds = Set(tasks.map(\.task_id))
        let requiredCount = activeMembers.count * tasks.count
        let completedCount = normalizedCompletions.filter { row in
            row.isCompleted &&
            row.date == dateString &&
            activeUserIds.contains(row.userId) &&
            taskIds.contains(row.taskId)
        }.count
        return DailyCompletionStatus(requiredCount: requiredCount, completedCount: completedCount)
    }

    private func saveTodayChallengeShaker(
        client: SupabaseClient,
        date: String,
        state: DailyShakerState,
        lidColorStart: String?,
        lidColorEnd: String?
    ) async throws {
        // Keep DB invariant: when not completed, lid colors must be null.
        let persistedLidStart = state.isCompleted ? lidColorStart : nil
        let persistedLidEnd = state.isCompleted ? lidColorEnd : nil

        let updatePayload = ChallengeShakerUpdatePayload(
            iscompleted: state.isCompleted,
            user_emojis: state.userEmojis,
            lid_color_start: persistedLidStart,
            lid_color_end: persistedLidEnd
        )
        let insertPayload = ChallengeShakerWritePayload(
            challenge_id: challengeId,
            date: date,
            iscompleted: state.isCompleted,
            user_emojis: state.userEmojis,
            lid_color_start: persistedLidStart,
            lid_color_end: persistedLidEnd
        )

        let rowId: UUID?
        if todayChallengeShakerRow?.date == date {
            rowId = todayChallengeShakerRow?.id
        } else {
            let rows: [ChallengeShakerRowId] = try await client
                .from("challenge_shaker")
                .select("id")
                .eq("challenge_id", value: challengeId.uuidString)
                .eq("date", value: date)
                .limit(1)
                .execute()
                .value
            rowId = rows.first?.id
        }

        if let rowId {
            try await client
                .from("challenge_shaker")
                .update(updatePayload)
                .eq("id", value: rowId.uuidString)
                .execute()
            todayChallengeShakerRow = ChallengeShakerRow(
                id: rowId,
                challenge_id: challengeId,
                date: date,
                iscompleted: state.isCompleted,
                user_emojis: state.userEmojis,
                lid_color_start: persistedLidStart,
                lid_color_end: persistedLidEnd
            )
            if let todayChallengeShakerRow {
                challengeShakerByDate[date] = todayChallengeShakerRow
            }
        } else {
            try await client
                .from("challenge_shaker")
                .insert(insertPayload)
                .execute()

            if let loaded = await fetchTodayChallengeShakerSafely(client: client, today: date) {
                todayChallengeShakerRow = loaded
                challengeShakerByDate[date] = loaded
            }
        }
    }

    private func fetchProofRowsSafely(client: SupabaseClient) async -> [ChallengeTaskProofPhotoData] {
        do {
            let rows: [ChallengeTaskProofPhotoData] = try await client
                .from("challenge_proof_photo")
                .select("*")
                .eq("challenge_id", value: challengeId.uuidString)
                .order("created_at", ascending: false)
                .limit(300)
                .execute()
                .value
            return rows
        } catch {
            // If table is not created yet, keep UI functional without proof state.
            return []
        }
    }

    private func fetchProfilesMapSafely(
        client: SupabaseClient,
        members: [ChallengeMemberData],
        additionalUserIds: [UUID] = []
    ) async -> [UUID: ProfileData] {
        let memberUserIds = members
            .filter { $0.left_at == nil }
            .map { $0.user_id }
        let allUserIds = Set(memberUserIds + additionalUserIds)
        guard !allUserIds.isEmpty else { return [:] }
        let userIds = allUserIds.map(\.uuidString)

        do {
            let profiles: [ProfileData] = try await client
                .from("profiles")
                .select("id, name, avatar_url")
                .in("id", value: userIds)
                .execute()
                .value

            var result: [UUID: ProfileData] = [:]
            for profile in profiles {
                result[profile.id] = profile
            }
            return result
        } catch {
            return [:]
        }
    }

    private func proofByTaskForCurrentUserToday(
        proofPhotos: [ChallengeTaskProofPhotoData],
        today: String
    ) -> [UUID: ChallengeTaskProofPhotoData] {
        guard let currentUserId else { return [:] }
        var result: [UUID: ChallengeTaskProofPhotoData] = [:]
        for proof in proofPhotos where proof.uploader_user_id == currentUserId && proof.proof_date == today {
            result[proof.task_id] = proof
        }
        return result
    }

    private func completionDayCountByUser(normalizedCompletions: [NormalizedCompletion]) -> [UUID: Int] {
        var daysByUser: [UUID: Set<String>] = [:]
        for completion in normalizedCompletions where completion.isCompleted {
            daysByUser[completion.userId, default: []].insert(completion.date)
        }
        var result: [UUID: Int] = [:]
        for (userId, days) in daysByUser {
            result[userId] = days.count
        }
        return result
    }

    private func buildCumulativeJarItems(
        normalizedCompletions: [NormalizedCompletion],
        activeMembers: [ChallengeMemberData],
        startDate: Date?,
        endDate: Date?,
        today: Date
    ) -> [JarItemUI] {
        let cal = Calendar.current
        let activeUserIds = Set(activeMembers.map(\.user_id))
        let normalizedStart = startDate.map { cal.startOfDay(for: $0) }
        let normalizedToday = cal.startOfDay(for: today)
        let normalizedEnd = endDate.map { cal.startOfDay(for: $0) }
        let effectiveEnd = min(normalizedEnd ?? normalizedToday, normalizedToday)

        var countsByUser: [UUID: Int] = [:]
        for row in normalizedCompletions where row.isCompleted {
            guard activeUserIds.contains(row.userId),
                  let rowDate = dateFromPostgreSQL(row.date).map({ cal.startOfDay(for: $0) })
            else { continue }

            if let normalizedStart, rowDate < normalizedStart { continue }
            if rowDate > effectiveEnd { continue }
            countsByUser[row.userId, default: 0] += 1
        }

        var result: [JarItemUI] = []
        for member in activeMembers.sorted(by: { $0.user_id.uuidString < $1.user_id.uuidString }) {
            let count = countsByUser[member.user_id] ?? 0
            guard count > 0 else { continue }
            let emoji = (member.member_emoji?.isEmpty == false) ? (member.member_emoji ?? "🙂") : "🙂"
            for _ in 0..<count {
                result.append(JarItemUI(id: UUID(), emoji: emoji))
            }
        }
        return result
    }

    private func buildDailyJarItems(
        normalizedCompletions: [NormalizedCompletion],
        activeMembers: [ChallengeMemberData],
        dateString: String
    ) -> [JarItemUI] {
        let activeUserIds = Set(activeMembers.map(\.user_id))
        let taskIds = Set(tasks.map(\.task_id))
        var countsByUser: [UUID: Int] = [:]

        for row in normalizedCompletions where row.isCompleted && row.date == dateString {
            guard activeUserIds.contains(row.userId), taskIds.contains(row.taskId) else { continue }
            countsByUser[row.userId, default: 0] += 1
        }

        var result: [JarItemUI] = []
        for member in activeMembers.sorted(by: { $0.user_id.uuidString < $1.user_id.uuidString }) {
            let count = countsByUser[member.user_id] ?? 0
            guard count > 0 else { continue }
            let emoji = (member.member_emoji?.isEmpty == false) ? (member.member_emoji ?? "🙂") : "🙂"
            for _ in 0..<count {
                result.append(JarItemUI(id: UUID(), emoji: emoji))
            }
        }
        return result
    }

    private func isTaskToggleAllowed(on date: Date) -> Bool {
        guard let challenge else { return false }
        let cal = Calendar.current
        let targetDay = cal.startOfDay(for: date)

        if let start = dateFromPostgreSQL(challenge.start_date).map({ cal.startOfDay(for: $0) }),
           targetDay < start {
            return false
        }

        if let end = dateFromPostgreSQL(challenge.end_date).map({ cal.startOfDay(for: $0) }),
           targetDay > end {
            return false
        }

        switch challenge.repeat_type.lowercased() {
        case "everyday", "daily":
            return true
        case "weekly":
            guard let weeklyDays = challenge.weekly_days, !weeklyDays.isEmpty else { return false }
            // DB convention: 0=Sun ... 6=Sat
            let weekday = cal.component(.weekday, from: targetDay) - 1
            return weeklyDays.contains(weekday)
        case "monthly":
            guard let monthlyDays = challenge.monthly_days, !monthlyDays.isEmpty else { return false }
            let dayOfMonth = cal.component(.day, from: targetDay)
            return monthlyDays.contains(dayOfMonth)
        default:
            return true
        }
    }

    private func parseDateTime(_ value: String?) -> Date? {
        guard let value else { return nil }
        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoWithFraction.date(from: value) {
            return d
        }

        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]
        if let d = isoBasic.date(from: value) {
            return d
        }

        // Postgres timestamptz can arrive as "yyyy-MM-dd HH:mm:ss.SSSSSS+00"
        let f1 = DateFormatter()
        f1.locale = Locale(identifier: "en_US_POSIX")
        f1.timeZone = TimeZone(secondsFromGMT: 0)
        f1.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX"
        if let d = f1.date(from: value) {
            return d
        }

        let f2 = DateFormatter()
        f2.locale = Locale(identifier: "en_US_POSIX")
        f2.timeZone = TimeZone(secondsFromGMT: 0)
        f2.dateFormat = "yyyy-MM-dd HH:mm:ssXXXXX"
        if let d = f2.date(from: value) {
            return d
        }

        let f3 = DateFormatter()
        f3.locale = Locale(identifier: "en_US_POSIX")
        f3.timeZone = TimeZone(secondsFromGMT: 0)
        f3.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        if let d = f3.date(from: value) {
            return d
        }

        return nil
    }

    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let cal = Calendar.current

        if cal.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }

        let startDate = cal.startOfDay(for: date)
        let startNow = cal.startOfDay(for: now)
        let rawDays = cal.dateComponents([.day], from: startDate, to: startNow).day ?? 0
        let days = max(1, rawDays)
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}
