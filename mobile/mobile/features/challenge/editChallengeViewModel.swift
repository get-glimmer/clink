import Foundation
import Supabase

// MARK: - ViewModel

@MainActor
class EditChallengeViewModel: ObservableObject {

    // MARK: Form fields
    @Published var challengeTitle: String = ""
    @Published var descriptionText: String = ""
    @Published var selectedShaker: ShakerType = .jar
    @Published var selectedProof: ProofType = .photoRequired
    @Published var dailyTasks: [String] = [""]

    // Duration
    @Published var fromDate: Date = Date()
    @Published var toDate: Date = Date()
    @Published var fromDateSelected: Bool = false
    @Published var toDateSelected: Bool = false

    // Repeat
    @Published var repeatType: RepeatType = .everyday
    @Published var selectedWeeklyDays: Set<Int> = []
    @Published var selectedMonthlyDays: Set<Int> = []

    // Active members (joined) and friends with a pending invite.
    @Published var members: [MemberInfo] = []
    @Published var pendingInvites: [PendingInviteInfo] = []

    // friendId → invite message; new friends to invite on save.
    @Published var invitedFriends: [String: String] = [:]

    // Emoji Setup
    @Published var emojiRule: EmojiRule = .selectedOnly
    @Published var presetEmojis: [String] = []

    // Status
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var didSaveSuccessfully: Bool = false
    @Published var didDeleteSuccessfully: Bool = false

    let challengeId: UUID
    private let client = SupabaseClientManager.shared.client

    // Snapshot of values as loaded — used to detect unsaved changes.
    private var _snapshotTitle: String = ""
    private var _snapshotDescription: String = ""
    private var _snapshotDailyTasks: [String] = []
    private var _snapshotFromDate: Date = Date()
    private var _snapshotFromDateSelected: Bool = false
    private var _snapshotToDate: Date = Date()
    private var _snapshotToDateSelected: Bool = false
    private var _snapshotRepeatType: RepeatType = .everyday
    private var _snapshotWeeklyDays: Set<Int> = []
    private var _snapshotMonthlyDays: Set<Int> = []
    private var _snapshotSelectedProof: ProofType = .photoRequired
    private var _snapshotPresetEmojis: [String] = []

    init(challengeId: UUID) {
        self.challengeId = challengeId
        Task { await loadChallenge() }  // Pre-populate form fields as soon as the VM is created.
    }

    var allInputsFilled: Bool {
        !challengeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && dailyTasks.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && fromDateSelected
            && toDateSelected
    }

    var hasChanges: Bool {
        challengeTitle != _snapshotTitle
            || descriptionText != _snapshotDescription
            || dailyTasks != _snapshotDailyTasks
            || fromDate != _snapshotFromDate
            || fromDateSelected != _snapshotFromDateSelected
            || toDate != _snapshotToDate
            || toDateSelected != _snapshotToDateSelected
            || repeatType != _snapshotRepeatType
            || selectedWeeklyDays != _snapshotWeeklyDays
            || selectedMonthlyDays != _snapshotMonthlyDays
            || selectedProof != _snapshotSelectedProof
            || presetEmojis != _snapshotPresetEmojis
            || !invitedFriends.isEmpty
    }

    // Total participants = active members + pending invites + newly added friends this session.
    var totalParticipantCount: Int {
        members.count + pendingInvites.count + invitedFriends.count
    }

    // "+" is shown only when there's room for a new participant's emoji slot.
    var canAddEmoji: Bool {
        emojiRule == .selectedOnly
            && totalParticipantCount > presetEmojis.count
            && presetEmojis.count < 10
    }

    var isSaveEnabled: Bool {
        hasChanges && allInputsFilled
    }

    // MARK: - Load existing challenge

    private func loadChallenge() async {
        guard let client = client else { return }
        isLoading = true

        do {
            let challenge: ChallengeRecord = try await client
                .from("challenges")
                .select()
                .eq("id", value: challengeId.uuidString)
                .single()
                .execute()
                .value

            challengeTitle = challenge.title
            descriptionText = challenge.description ?? ""

            // Map DB string values back to Swift enums; fall back to defaults if unrecognised.
            if let st = ShakerType(rawValue: challenge.shaker_type) { selectedShaker = st }
            if let pt = ProofType(rawValue: challenge.proof_type)   { selectedProof  = pt }
            if let rt = RepeatType(rawValue: challenge.repeat_type) { repeatType     = rt }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let sd = challenge.start_date, let d = formatter.date(from: sd) {
                fromDate = d; fromDateSelected = true
            }
            if let ed = challenge.end_date, let d = formatter.date(from: ed) {
                toDate = d; toDateSelected = true
            }

            if let wd = challenge.weekly_days  { selectedWeeklyDays  = Set(wd) }
            if let md = challenge.monthly_days { selectedMonthlyDays = Set(md) }
            emojiRule    = EmojiRule(rawValue: challenge.emoji_rule ?? "selected_only") ?? .selectedOnly
            presetEmojis = challenge.preset_emojis ?? []

            let tasks: [ChallengeTaskRecord] = try await client
                .from("challenge_task")
                .select()
                .eq("challenge_id", value: challengeId.uuidString)
                .order("sortorder", ascending: true)
                .execute()
                .value

            let loaded = tasks.compactMap { $0.task_title }.filter { !$0.isEmpty }
            dailyTasks = loaded.isEmpty ? [""] : loaded  // Always keep at least one empty row in the UI.

            // Fetch active members (left_at == nil) and resolve their profiles in one batch.
            let activeMembers: [ChallengeMemberData] = try await client
                .from("challenge_members")
                .select("*")
                .eq("challenge_id", value: challengeId.uuidString)
                .is("left_at", value: nil)
                .execute()
                .value

            let memberUserIds = activeMembers.map { $0.user_id.uuidString }

            var profilesMap: [String: ProfileData] = [:]
            if !memberUserIds.isEmpty {
                let profiles: [ProfileData] = try await client
                    .from("profiles")
                    .select("id, name, avatar_url")
                    .in("id", value: memberUserIds)
                    .execute()
                    .value
                for profile in profiles {
                    profilesMap[profile.id.uuidString] = profile
                }
            }

            members = activeMembers.map { member in
                let profile = profilesMap[member.user_id.uuidString]
                return MemberInfo(
                    userId: member.user_id,
                    name: profile?.name,
                    avatarUrl: profile?.avatar_url,
                    emoji: member.member_emoji,
                    role: member.role
                )
            }

            // Fetch only pending invites for this challenge and resolve invitee profiles in one batch.
            let inviteRecords: [ChallengeInviteRecord] = try await client
                .from("challenge_invites")
                .select("id, invitee_user_id, status")
                .eq("challenge_id", value: challengeId.uuidString)
                .eq("status", value: "pending")
                .execute()
                .value

            let inviteeIds = inviteRecords.compactMap { $0.invitee_user_id?.uuidString }
            var inviteeProfilesMap: [String: ProfileData] = [:]
            if !inviteeIds.isEmpty {
                let inviteeProfiles: [ProfileData] = try await client
                    .from("profiles")
                    .select("id, name, avatar_url")
                    .in("id", value: inviteeIds)
                    .execute()
                    .value
                for profile in inviteeProfiles {
                    inviteeProfilesMap[profile.id.uuidString] = profile
                }
            }

            pendingInvites = inviteRecords.map { invite in
                let profile = invite.invitee_user_id.flatMap { inviteeProfilesMap[$0.uuidString] }
                return PendingInviteInfo(
                    id: invite.id,
                    userId: invite.invitee_user_id,
                    name: profile?.name,
                    avatarUrl: profile?.avatar_url,
                    status: invite.status
                )
            }

            // Snapshot all loaded values so hasChanges can detect edits.
            _snapshotTitle = challengeTitle
            _snapshotDescription = descriptionText
            _snapshotDailyTasks = dailyTasks
            _snapshotFromDate = fromDate
            _snapshotFromDateSelected = fromDateSelected
            _snapshotToDate = toDate
            _snapshotToDateSelected = toDateSelected
            _snapshotRepeatType = repeatType
            _snapshotWeeklyDays = selectedWeeklyDays
            _snapshotMonthlyDays = selectedMonthlyDays
            _snapshotSelectedProof = selectedProof
            _snapshotPresetEmojis = presetEmojis

        } catch {
            errorMessage = "Failed to load challenge: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Save changes

    func updateChallenge() async {
        guard let client = client else { return }
        isSaving = true
        errorMessage = nil

        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            let startDate   = fromDateSelected ? formatter.string(from: fromDate) : nil
            let endDate     = toDateSelected   ? formatter.string(from: toDate)   : nil
            let trimmedDesc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

            let payload = ChallengeUpdate(
                title: challengeTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                shaker_type: selectedShaker.rawValue,
                proof_type:  selectedProof.rawValue,
                start_date:  startDate,
                end_date:    endDate,
                repeat_type: repeatType.rawValue,
                weekly_days:  repeatType == .weekly  ? selectedWeeklyDays.sorted()  : nil,
                monthly_days: repeatType == .monthly ? selectedMonthlyDays.sorted() : nil,
                preset_emojis: presetEmojis.isEmpty ? nil : presetEmojis
            )

            try await client
                .from("challenges")
                .update(payload)
                .eq("id", value: challengeId.uuidString)
                .execute()

            // For any_emoji rule, the owner's chosen emoji IS the representative emoji —
            // keep challenge_members.member_emoji in sync when it changes.
            if emojiRule == .anyEmoji,
               let newEmoji = presetEmojis.first,
               !newEmoji.isEmpty,
               newEmoji != _snapshotPresetEmojis.first,
               let session = try? await client.auth.session {
                try await client
                    .from("challenge_members")
                    .update(["member_emoji": newEmoji])
                    .eq("challenge_id", value: challengeId.uuidString)
                    .eq("user_id", value: session.user.id.uuidString)
                    .execute()
            }

            // Simpler than diffing individual rows: delete all existing tasks and re-insert
            // with fresh sequential sortorders (0, 1, 2…).
            try await client
                .from("challenge_task")
                .delete()
                .eq("challenge_id", value: challengeId.uuidString)
                .execute()

            let validTasks: [ChallengeTaskInsert] = dailyTasks
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { sortorder, title in
                    ChallengeTaskInsert(challenge_id: challengeId, task_title: title, sortorder: sortorder)
                }

            if !validTasks.isEmpty {
                try await client
                    .from("challenge_task")
                    .insert(validTasks)
                    .execute()
            }

            // Insert pending invites for newly selected friends (skip already invited or already joined).
            if !invitedFriends.isEmpty,
               let session = try? await client.auth.session {
                let inviterUserId = session.user.id
                let existingInviteeIds = Set(pendingInvites.compactMap { $0.userId?.uuidString })
                let existingMemberIds = Set(members.map { $0.userId.uuidString })

                for (friendIdString, message) in invitedFriends {
                    guard !existingInviteeIds.contains(friendIdString),
                          !existingMemberIds.contains(friendIdString),
                          let friendUUID = UUID(uuidString: friendIdString) else { continue }

                    let invite = ChallengeInviteInsert(
                        challenge_id: challengeId,
                        inviter_user_id: inviterUserId,
                        invitee_user_id: friendUUID,
                        message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message
                    )
                    try await client
                        .from("challenge_invites")
                        .insert(invite)
                        .execute()
                }
            }

            didSaveSuccessfully = true

        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }

        isSaving = false
    }

    // MARK: - Delete challenge

    func deleteChallenge() async {
        guard let client = client else { return }

        do {
            try await client
                .from("challenges")
                .delete()
                .eq("id", value: challengeId.uuidString)
                .execute()

            didDeleteSuccessfully = true
        } catch {
            errorMessage = "Failed to delete challenge: \(error.localizedDescription)"
        }
    }

    // MARK: - Remove member

    func removeMember(userId: UUID) async {
        guard let client = client else { return }
        do {
            try await client
                .from("challenge_members")
                .delete()
                .eq("challenge_id", value: challengeId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
            members.removeAll { $0.userId == userId }
        } catch {
            errorMessage = "Failed to remove member: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete invite

    func deleteInvite(inviteId: UUID) async {
        guard let client = client else { return }
        do {
            try await client
                .from("challenge_invites")
                .delete()
                .eq("id", value: inviteId.uuidString)
                .execute()
            pendingInvites.removeAll { $0.id == inviteId }
        } catch {
            errorMessage = "Failed to remove invite: \(error.localizedDescription)"
        }
    }

    func toggleWeeklyDay(_ day: Int) {
        if selectedWeeklyDays.contains(day) { selectedWeeklyDays.remove(day) }
        else { selectedWeeklyDays.insert(day) }
    }

    func toggleMonthlyDay(_ day: Int) {
        if selectedMonthlyDays.contains(day) { selectedMonthlyDays.remove(day) }
        else { selectedMonthlyDays.insert(day) }
    }
}
