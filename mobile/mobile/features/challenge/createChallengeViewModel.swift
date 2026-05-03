import Foundation
import Supabase

// MARK: - ViewModel

@MainActor
class CreateChallengeViewModel: ObservableObject {

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
    @Published var selectedWeeklyDays: Set<Int> = []   // 0 = Sun … 6 = Sat
    @Published var selectedMonthlyDays: Set<Int> = []  // 1 … 31

    // friendId → invite message; persisted here so state survives sheet dismissal.
    @Published var invitedFriends: [String: String] = [:]

    // Emoji Setup
    @Published var emojiRule: EmojiRule = .selectedOnly
    @Published var selectedEmojis: [String] = []   // rule 1 — preset pool for participants
    @Published var singleEmoji: String = ""          // rule 2 — representative emoji

    // Status
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var didCreateSuccessfully: Bool = false

    // Owner's chosen emoji — set before createChallenge() is called
    @Published var ownerEmoji: String = ""

    private let client = SupabaseClientManager.shared.client

    // Min emojis = total participants (invited + owner), max 10.
    var minEmojiCount: Int { max(invitedFriends.count + 1, 1) }

    var isEmojiSetupValid: Bool {
        switch emojiRule {
        case .selectedOnly: return selectedEmojis.count >= minEmojiCount && selectedEmojis.count <= 10
        case .anyEmoji:     return true  // creator picks emoji later in MemberEmojiSetupView
        }
    }

    // Create button is active only when all required fields are filled.
    var isCreateEnabled: Bool {
        !challengeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && dailyTasks.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && fromDateSelected
            && toDateSelected
    }

    // Human-readable label shown in the Repeat row (e.g. "Mon, Wed" or "1, 15").
    var repeatDisplayValue: String {
        switch repeatType {
        case .everyday:
            return "Everyday"
        case .weekly:
            guard !selectedWeeklyDays.isEmpty else { return "Weekly" }
            let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return selectedWeeklyDays.sorted().map { names[$0] }.joined(separator: ", ")
        case .monthly:
            guard !selectedMonthlyDays.isEmpty else { return "Monthly" }
            return selectedMonthlyDays.sorted().map { "\($0)" }.joined(separator: ", ")
        }
    }

    func toggleWeeklyDay(_ day: Int) {
        if selectedWeeklyDays.contains(day) {
            selectedWeeklyDays.remove(day)
        } else {
            selectedWeeklyDays.insert(day)
        }
    }

    func toggleMonthlyDay(_ day: Int) {
        if selectedMonthlyDays.contains(day) {
            selectedMonthlyDays.remove(day)
        } else {
            selectedMonthlyDays.insert(day)
        }
    }

    // MARK: - Create challenge

    // Validates the form and triggers navigation to emoji picker — no DB writes yet.
    // MARK: - Create challenge

    func createChallenge() async {
        guard let client = client else {
            errorMessage = "Not connected to server."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let session = try await client.auth.session
            let userId = session.user.id

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            let startDate   = fromDateSelected ? formatter.string(from: fromDate) : nil
            let endDate     = toDateSelected   ? formatter.string(from: toDate)   : nil
            let trimmedDesc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

            let presetEmojis: [String]? = {
                switch emojiRule {
                case .selectedOnly: return selectedEmojis.isEmpty ? nil : selectedEmojis
                case .anyEmoji:     return singleEmoji.isEmpty   ? nil : [singleEmoji]
                }
            }()

            let payload = ChallengeInsert(
                owner_user_id: userId,
                title: challengeTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                shaker_type: selectedShaker.rawValue,
                proof_type: selectedProof.rawValue,
                start_date: startDate,
                end_date: endDate,
                repeat_type: repeatType.rawValue,
                weekly_days:  repeatType == .weekly  ? selectedWeeklyDays.sorted()  : nil,
                monthly_days: repeatType == .monthly ? selectedMonthlyDays.sorted() : nil,
                emoji_rule: emojiRule.rawValue,
                preset_emojis: presetEmojis
            )

            let inserted: ChallengeResponse = try await client
                .from("challenges")
                .insert(payload)
                .select("id")
                .single()
                .execute()
                .value

            let validTasks: [ChallengeTaskInsert] = dailyTasks
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { sortorder, title in
                    ChallengeTaskInsert(
                        challenge_id: inserted.id,
                        task_title: title,
                        sortorder: sortorder
                    )
                }

            if !validTasks.isEmpty {
                try await client
                    .from("challenge_task")
                    .insert(validTasks)
                    .execute()
            }

            let memberPayload = ChallengeMemberInsert(
                challenge_id: inserted.id,
                user_id: userId,
                role: "owner",
                member_emoji: ownerEmoji.isEmpty ? nil : ownerEmoji
            )
            try await client
                .from("challenge_members")
                .insert(memberPayload)
                .execute()

            print("[Challenges] ✅ Challenge created: '\(challengeTitle.trimmingCharacters(in: .whitespacesAndNewlines))' (id: \(inserted.id))")

            for (friendIdString, message) in invitedFriends {
                guard let friendUUID = UUID(uuidString: friendIdString) else { continue }
                let invite = ChallengeInviteInsert(
                    challenge_id: inserted.id,
                    inviter_user_id: userId,
                    invitee_user_id: friendUUID,
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message
                )
                try await client
                    .from("challenge_invites")
                    .insert(invite)
                    .execute()
                print("[Challenges] 📨 Invite sent to userId: \(friendIdString) for challenge id: \(inserted.id)")
            }

            completeCreation()

        } catch {
            errorMessage = "Failed to create challenge: \(error.localizedDescription)"
            print("❌ createChallenge error: \(error)")
        }

        isLoading = false
    }

    func completeCreation() {
        didCreateSuccessfully = true
    }
}
