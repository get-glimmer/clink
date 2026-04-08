import SwiftUI
import Supabase

class ChallengeViewModel: ObservableObject {
    @Published var challenges: [ChallengeItem] = []
    @Published var pendingInvites: [InvitedChallengeItem] = []
    @Published var pendingInviteForOverlay: InvitedChallengeItem? = nil
    @Published var showPendingInviteOverlay: Bool = false
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
    private var didDismissPendingInviteOverlay = false

    let categories = ["Challenges", "My Challenges", "Completed", "Invited"]
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

    func dismissPendingInviteOverlay() {
        showPendingInviteOverlay = false
        didDismissPendingInviteOverlay = true
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

                async let pendingInvitesTask: [InvitedChallengeItem] = {
                    (try? await challengeService.fetchPendingInvites()) ?? []
                }()

                if self.selectedCategory == "Invited" {
                    let invites = await pendingInvitesTask
                    await MainActor.run {
                        self.updatePendingInvites(invites)
                        self.isLoading = false
                    }
                } else {
                    let fetched: [ChallengeItem]
                    switch self.selectedCategory {
                    case "My Challenges":
                        fetched = try await challengeService.fetchMyChallenges()
                    case "Completed":
                        fetched = try await challengeService.fetchCompletedChallenges()
                    default:
                        fetched = try await challengeService.fetchChallenges()
                    }

                    let invites = await pendingInvitesTask
                    await MainActor.run {
                        self.challenges = fetched
                        self.updatePendingInvites(invites)
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load challenges: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func updatePendingInvites(_ invites: [InvitedChallengeItem]) {
        pendingInvites = invites

        guard let first = invites.first else {
            pendingInviteForOverlay = nil
            showPendingInviteOverlay = false
            didDismissPendingInviteOverlay = false
            return
        }

        pendingInviteForOverlay = first
        if !didDismissPendingInviteOverlay {
            showPendingInviteOverlay = true
        }
    }

}
