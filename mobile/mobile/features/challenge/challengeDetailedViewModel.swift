import Foundation
import SwiftUI
import Supabase
import UIKit

struct WeeklyDayUI: Identifiable {
    enum Status { case all, partial, none }

    let id = UUID()
    let weekday: String
    let day: String
    let status: Status
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
    @Published var todayTasks: [TodayTaskUI] = []
    @Published var participants: [ChallengeParticipantUI] = []
    @Published var galleryItems: [ChallengeGalleryItemUI] = []
    @Published var communityComments: [ChallengeCommentUI] = []
    @Published var commentDraft: String = ""
    @Published var isSendingComment = false
    @Published var currentUserAvatarURL: String?
    @Published var isPhotoProofEnabled = true

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

    init(challengeId: UUID) {
        self.challengeId = challengeId
    }

    func load() async {
        await fetchAll(showLoading: true)
    }

    func refreshAfterMutation() async {
        await fetchAll(showLoading: false)
    }

    func toggleTask(taskId: UUID) {
        guard isTaskToggleAllowed(on: Date()) else { return }
        guard let idx = todayTasks.firstIndex(where: { $0.id == taskId }) else { return }
        todayTasks[idx].isCompleted.toggle()
    }

    func uploadProofImage(taskId: UUID, image: UIImage) async {
        guard let client, let userId = currentUserId else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process selected image."
            return
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
                return
            }
            
            guard let proofURL = try? client.storage
                .from("challenge-proofs")
                .getPublicURL(path: filePath).absoluteString else {
                errorMessage = "Failed to get proof image URL."
                return
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

            await refreshAfterMutation()
        } catch {
            errorMessage = "Proof metadata save failed (table RLS/policy): \(error.localizedDescription)"
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
            tasks = try await taskRows
            completions = try await completionRows
            comments = (try? await commentRows) ?? []
            proofPhotos = await fetchProofRowsSafely(client: client)
            let commenterIds = comments.compactMap { $0.commenter_id }
            profilesByUserId = await fetchProfilesMapSafely(
                client: client,
                members: members,
                additionalUserIds: commenterIds
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
        isPhotoProofEnabled = challenge.proof_type.lowercased() == "photo_upload"
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
                ChallengeGalleryItemUI(
                    id: proof.id,
                    imageURL: proof.proof_url,
                    createdAt: parseDateTime(proof.created_at) ?? .distantPast
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

        weekly = buildWeeklyRows(
            normalizedCompletions: normalizedCompletions,
            activeMemberCount: activeMembers.count,
            taskCount: tasks.count,
            today: today
        )

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

    private func buildWeeklyRows(
        normalizedCompletions: [NormalizedCompletion],
        activeMemberCount: Int,
        taskCount: Int,
        today: Date
    ) -> [WeeklyDayUI] {
        let calendar = Calendar.current
        let startOfWeek = calendar.startOfWeek(for: today)
        let weekdayLabels = calendar.shortStandaloneWeekdaySymbols.map { $0.uppercased() }
        let requiredCount = activeMemberCount * taskCount

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { return nil }
            let dateKey = formattedDate(date)
            let dayCompletions = normalizedCompletions.filter { $0.date == dateKey && $0.isCompleted }
            let completedCount = dayCompletions.count

            let status: WeeklyDayUI.Status
            if requiredCount == 0 || completedCount == 0 {
                status = .none
            } else if completedCount >= requiredCount {
                status = .all
            } else {
                status = .partial
            }

            return WeeklyDayUI(
                weekday: weekdayLabels[offset],
                day: String(calendar.component(.day, from: date)),
                status: status,
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
