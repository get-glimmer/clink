import SwiftUI
import Supabase

class ChallengeViewModel: ObservableObject {
    @Published var challenges: [ChallengeItem] = []
    @Published var selectedCategory: String = "Challenges"
    @Published var isDropdownPresented: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Options menu state
    @Published var showOptionsMenu: Bool = false
    @Published var showCreateChallenge: Bool = false

    // Quit challenge state
    @Published var challengeToQuit: ChallengeItem? = nil
    @Published var showQuitConfirmation: Bool = false

    // DEV ONLY: edit challenge state
    @Published var showEditChallenge: Bool = false
    @Published var selectedChallengeId: UUID? = nil

    // Used to determine ownership for edit access.
    private(set) var currentUserId: UUID? = nil

    let categories = ["Challenges", "My Challenges", "Completed"]
    private let challengeService = ChallengeService()

    init() {
        loadChallenges(refresh: false)
    }

    // MARK: - Public

    func selectCategory(_ category: String) {
        selectedCategory = category
        isDropdownPresented = false
        loadChallenges(refresh: false)
    }

    func toggleDropdown() {
        isDropdownPresented.toggle()
    }

    func refreshChallenges() {
        loadChallenges(refresh: true)
    }

    func toggleOptionsMenu() {
        showOptionsMenu.toggle()
    }

    func requestQuit(challenge: ChallengeItem) {
        challengeToQuit = challenge
        showQuitConfirmation = true
    }

    func confirmQuitChallenge() {
        guard let challenge = challengeToQuit else { return }
        Task {
            do {
                await challengeService.initializeService()
                try await challengeService.quitChallenge(challenge.id)
                await MainActor.run {
                    self.challenges.removeAll { $0.id == challenge.id }
                    self.challengeToQuit = nil
                    self.showQuitConfirmation = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to quit challenge: \(error.localizedDescription)"
                    self.challengeToQuit = nil
                    self.showQuitConfirmation = false
                }
            }
        }
    }

    func cancelQuit() {
        challengeToQuit = nil
        showQuitConfirmation = false
    }

    // MARK: - Private

    private func loadChallenges(refresh: Bool) {
        Task {
            await MainActor.run {
                if !refresh { self.isLoading = true }
                self.errorMessage = nil
            }

            do {
                // Make sure the service has the current user
                await challengeService.initializeService()

                if self.currentUserId == nil,
                   let session = try? await SupabaseClientManager.shared.client?.auth.session {
                    await MainActor.run { self.currentUserId = session.user.id }
                }

                let fetched: [ChallengeItem]
                switch self.selectedCategory {
                case "My Challenges":
                    fetched = try await challengeService.fetchMyChallenges()
                case "Completed":
                    fetched = try await challengeService.fetchCompletedChallenges()
                default:
                    fetched = try await challengeService.fetchChallenges()
                }

                await MainActor.run {
                    self.challenges = fetched
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load challenges: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

}
