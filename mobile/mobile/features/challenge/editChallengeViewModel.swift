import Foundation
import Supabase

// MARK: - ViewModel

@MainActor
class EditChallengeViewModel: ObservableObject {

    // MARK: Form fields
    @Published var challengeTitle: String = ""
    @Published var descriptionText: String = ""
    @Published var selectedShaker: ShakerType = .jar
    @Published var selectedProof: ProofType = .photo
    @Published var isProofRequired: Bool = true
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

    // Status
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var didSaveSuccessfully: Bool = false
    @Published var didDeleteSuccessfully: Bool = false

    let challengeId: UUID
    private let client = SupabaseClientManager.shared.client

    init(challengeId: UUID) {
        self.challengeId = challengeId
        Task { await loadChallenge() }  // Pre-populate form fields as soon as the VM is created.
    }

    var isSaveEnabled: Bool {
        !challengeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

            let tasks: [ChallengeTaskRecord] = try await client
                .from("challenge_task")
                .select()
                .eq("challenge_id", value: challengeId.uuidString)
                .order("sortorder", ascending: true)
                .execute()
                .value

            let loaded = tasks.compactMap { $0.task_title }.filter { !$0.isEmpty }
            dailyTasks = loaded.isEmpty ? [""] : loaded  // Always keep at least one empty row in the UI.

        } catch {
            errorMessage = "Failed to load challenge: \(error.localizedDescription)"
            print("❌ loadChallenge error: \(error)")
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
                monthly_days: repeatType == .monthly ? selectedMonthlyDays.sorted() : nil
            )

            try await client
                .from("challenges")
                .update(payload)
                .eq("id", value: challengeId.uuidString)
                .execute()

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

            didSaveSuccessfully = true

        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            print("❌ updateChallenge error: \(error)")
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
            print("❌ deleteChallenge error: \(error)")
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
