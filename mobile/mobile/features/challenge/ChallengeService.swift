import Foundation
import Supabase

// MARK: - Challenge Service

class ChallengeService: ObservableObject {
    private var supabase: SupabaseClient? {
        return SupabaseClientManager.shared.client
    }

    private var currentUserId: String?

    init() {
        Task {
            await initializeService()
        }
    }

    @MainActor
    func initializeService() async {
        do {
            if let user = try await supabase?.auth.session.user {
                self.currentUserId = user.id.uuidString
            }
        } catch {
            print("ChallengeService: Error getting current user: \(error)")
        }
    }

    // MARK: - Fetch All Challenges (owned only)

    func fetchChallenges() async throws -> [ChallengeItem] {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "ChallengeService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Service not properly initialized"])
        }

        let challenges: [ChallengeData] = try await supabase
            .from("challenges")
            .select("*")
            .eq("owner_user_id", value: currentUserId)
            .order("end_date", ascending: true)
            .execute()
            .value

        var items: [ChallengeItem] = []
        for challenge in challenges {
            let item = try await assembleItem(challenge: challenge, supabase: supabase)
            items.append(item)
        }

        print("[Challenges] fetchChallenges: \(items.count) challenge(s) for userId: \(currentUserId)")
        return items
    }

    // MARK: - Fetch My Challenges (owner)

    func fetchMyChallenges() async throws -> [ChallengeItem] {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "ChallengeService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Service not properly initialized"])
        }

        let challenges: [ChallengeData] = try await supabase
            .from("challenges")
            .select("*")
            .eq("owner_user_id", value: currentUserId)
            .execute()
            .value
        
        print("My id: \(currentUserId)")

        var items: [ChallengeItem] = []
        for challenge in challenges {
            let item = try await assembleItem(challenge: challenge, supabase: supabase)
            items.append(item)
        }
        return items
    }

    // MARK: - Fetch Completed Challenges

    func fetchCompletedChallenges() async throws -> [ChallengeItem] {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "ChallengeService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Service not properly initialized"])
        }

        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // "YYYY-MM-DD"

        // Challenges this user is a member of AND end_date < today
        let allMemberships: [ChallengeMemberData] = try await supabase
            .from("challenge_members")
            .select("*")
            .eq("user_id", value: currentUserId)
            .execute()
            .value

        let memberships = allMemberships.filter { $0.left_at == nil }
        let challengeIds = memberships.map { $0.challenge_id.uuidString }
        guard !challengeIds.isEmpty else { return [] }

        let challenges: [ChallengeData] = try await supabase
            .from("challenges")
            .select("*")
            .in("id", value: challengeIds)
            .lt("end_date", value: String(today))
            .execute()
            .value

        var items: [ChallengeItem] = []
        for challenge in challenges {
            let item = try await assembleItem(challenge: challenge, supabase: supabase)
            items.append(item)
        }
        return items
    }

    // MARK: - Fetch Pending Invites (challenges this user was invited to but hasn't accepted)

    func fetchPendingInvites() async throws -> [InvitedChallengeItem] {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "ChallengeService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Service not properly initialized"])
        }

        let invites: [InviteData] = try await supabase
            .from("challenge_invites")
            .select("id, challenge_id, inviter_user_id, message, status")
            .eq("invitee_user_id", value: currentUserId)
            .eq("status", value: "pending")
            .execute()
            .value

        guard !invites.isEmpty else { return [] }

        let challengeIds = invites.map { $0.challenge_id.uuidString }
        let challenges: [ChallengeData] = try await supabase
            .from("challenges")
            .select("*")
            .in("id", value: challengeIds)
            .execute()
            .value

        let inviterIds = invites.map { $0.inviter_user_id.uuidString }
        let inviterProfiles: [ProfileData] = try await supabase
            .from("profiles")
            .select("id, name, avatar_url")
            .in("id", value: inviterIds)
            .execute()
            .value
        let profilesMap = Dictionary(uniqueKeysWithValues: inviterProfiles.map { ($0.id.uuidString, $0) })

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var items: [InvitedChallengeItem] = []
        for invite in invites {
            guard let challenge = challenges.first(where: { $0.id == invite.challenge_id }) else { continue }

            let allMembers: [ChallengeMemberData] = try await supabase
                .from("challenge_members")
                .select("*")
                .eq("challenge_id", value: challenge.id.uuidString)
                .execute()
                .value
            let activeMemberCount = allMembers.filter { $0.left_at == nil }.count

            let emojiRule = EmojiRule(rawValue: challenge.emoji_rule ?? "selected_only") ?? .selectedOnly
            let inviterName = profilesMap[invite.inviter_user_id.uuidString]?.name

            items.append(InvitedChallengeItem(
                id: invite.id,
                challengeId: challenge.id,
                title: challenge.title,
                description: challenge.description,
                startDate: challenge.start_date.flatMap { dateFormatter.date(from: $0) },
                endDate: challenge.end_date.flatMap { dateFormatter.date(from: $0) },
                frequency: challenge.frequencyText,
                emojiRule: emojiRule,
                presetEmojis: challenge.preset_emojis ?? [],
                memberCount: activeMemberCount,
                inviterName: inviterName,
                message: invite.message
            ))
        }

        print("[Challenges] fetchPendingInvites: \(items.count) pending invite(s)")
        return items
    }

    // MARK: - Quit Challenge (set left_at on the current user's membership)

    func quitChallenge(_ challengeId: UUID) async throws {
        guard let supabase = supabase,
              let currentUserId = currentUserId else {
            throw NSError(domain: "ChallengeService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Service not properly initialized"])
        }

        let now = ISO8601DateFormatter().string(from: Date())

        try await supabase
            .from("challenge_members")
            .update(["left_at": now])
            .eq("challenge_id", value: challengeId.uuidString)
            .eq("user_id", value: currentUserId)
            .execute()
    }

    // MARK: - Private Helpers

    private func assembleItem(challenge: ChallengeData, supabase: SupabaseClient) async throws -> ChallengeItem {
        // Members (no join — FK goes through auth.users, not profiles)
        let allMembers: [ChallengeMemberData] = try await supabase
            .from("challenge_members")
            .select("*")
            .eq("challenge_id", value: challenge.id.uuidString)
            .execute()
            .value

        let activeMembers = allMembers.filter { $0.left_at == nil }

        // Fetch profiles for active members
        let memberUserIds = activeMembers.map { $0.user_id.uuidString }
        var profilesMap: [String: ProfileData] = [:]
        if !memberUserIds.isEmpty {
            let profiles: [ProfileData] = try await supabase
                .from("profiles")
                .select("id, name, avatar_url")
                .in("id", value: memberUserIds)
                .execute()
                .value
            for profile in profiles {
                profilesMap[profile.id.uuidString] = profile
            }
        }

        let members = activeMembers.map { member in
            let profile = profilesMap[member.user_id.uuidString]
            return MemberInfo(
                userId: member.user_id,
                name: profile?.name,
                avatarUrl: profile?.avatar_url,
                emoji: member.member_emoji,
                role: member.role
            )
        }

        // Tasks
        let tasks: [ChallengeTaskData] = try await supabase
            .from("challenge_task")
            .select("*")
            .eq("challenge_id", value: challenge.id.uuidString)
            .execute()
            .value

        // Completions
        let completions: [ChallengeTaskCompletionData] = try await supabase
            .from("challenge_task_completion")
            .select("*")
            .eq("challenge_id", value: challenge.id.uuidString)
            .eq("is_completed", value: true)
            .execute()
            .value

        // Challenge Shaker (for current user, today)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())

        // challenge_shaker has no user_id column — it's per challenge per
        // date, so we don't need (and shouldn't gate on) currentUserId.
        var shakerRow: ChallengeShakerData? = nil
        do {
            // Use the challenge's end date as the upper bound when the
            // challenge is already over, otherwise today. This way the
            // preview reflects the final jar state for completed
            // challenges and the most recent state for in-progress ones.
            let upperBoundStr: String = {
                if let end = challenge.end_date.flatMap({ dateFormatter.date(from: $0) }),
                   Calendar.current.startOfDay(for: end) < Calendar.current.startOfDay(for: Date()) {
                    return dateFormatter.string(from: end)
                }
                return todayStr
            }()

            let shakerRows: [ChallengeShakerData] = try await supabase
                .from("challenge_shaker")
                .select("*")
                .eq("challenge_id", value: challenge.id.uuidString)
                .lte("date", value: upperBoundStr)
                .order("date", ascending: false)
                .limit(1)
                .execute()
                .value
            shakerRow = shakerRows.first
            print("[ChallengeShaker] challenge=\(challenge.id) title=\(challenge.title) upper=\(upperBoundStr) rows=\(shakerRows.count) isCompleted=\(shakerRow?.iscompleted ?? false) emojis=\(shakerRow?.user_emojis ?? []) lidStart=\(shakerRow?.lid_color_start ?? "nil") lidEnd=\(shakerRow?.lid_color_end ?? "nil")")
        } catch {
            print("[ChallengeShaker] fetch FAILED for challenge=\(challenge.id): \(error)")
        }

        // Parse dates
        let startDate = challenge.start_date.flatMap { dateFormatter.date(from: $0) }
        let endDate = challenge.end_date.flatMap { dateFormatter.date(from: $0) }

        // Build jar emoji list from completions, the same way the detail
        // view does. challenge_shaker.user_emojis is never written by the
        // app, so we compute the preview jar from challenge_task_completion:
        // one emoji per completed task, mapped to that member's member_emoji.
        // Range = [start_date, min(end_date, today)] (inclusive on both ends).
        let upperJarBoundStr: String = {
            if let end = endDate,
               Calendar.current.startOfDay(for: end) < Calendar.current.startOfDay(for: Date()) {
                return dateFormatter.string(from: end)
            }
            return todayStr
        }()
        let lowerJarBoundStr: String = startDate.map { dateFormatter.string(from: $0) } ?? ""

        let memberEmojiByUser: [UUID: String] = Dictionary(
            uniqueKeysWithValues: activeMembers.map { ($0.user_id, ($0.member_emoji?.isEmpty == false) ? ($0.member_emoji ?? "🙂") : "🙂") }
        )

        let jarEmojis: [String] = completions.compactMap { row in
            guard let userId = row.user_id, let date = row.date else { return nil }
            if !lowerJarBoundStr.isEmpty, date < lowerJarBoundStr { return nil }
            if date > upperJarBoundStr { return nil }
            return memberEmojiByUser[userId] ?? "🙂"
        }
        print("[ChallengeJar] challenge=\(challenge.id) title=\(challenge.title) range=\(lowerJarBoundStr)..\(upperJarBoundStr) completions=\(completions.count) jarEmojis=\(jarEmojis)")

        return ChallengeItem(
            id: challenge.id,
            ownerUserId: challenge.owner_user_id,
            title: challenge.title,
            description: challenge.description,
            startDate: startDate,
            endDate: endDate,
            frequency: challenge.frequencyText,
            shakerType: challenge.shaker_type,
            memberCount: members.count,
            members: members,
            taskCount: tasks.count,
            completedTaskCount: completions.count,
            shakerIsCompleted: shakerRow?.iscompleted ?? false,
            shakerUserEmojis: jarEmojis,
            shakerLidColorStart: shakerRow?.lid_color_start,
            shakerLidColorEnd: shakerRow?.lid_color_end
        )
    }
}
