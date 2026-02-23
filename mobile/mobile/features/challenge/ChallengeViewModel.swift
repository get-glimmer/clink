import SwiftUI
import Supabase

class ChallengeViewModel: ObservableObject {
    @Published var challenges: [ChallengeItem] = []
    @Published var selectedCategory: String = "Challenges"
    @Published var isDropdownPresented: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

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

                let fetched = try await challengeService.fetchChallenges()

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
