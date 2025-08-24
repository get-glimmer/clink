import SwiftUI

@MainActor
class UsernameViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var isLoading = false

    func updateName(authViewModel: AuthViewModel) async {
        guard !name.isEmpty else { return }
        isLoading = true

        do {
            try await authViewModel.updateName(name)
            // Keep local TextField in sync
            name = authViewModel.profile?.name ?? name
            print("✅ Name updated in ViewModel: \(name)")
        } catch {
            print("❌ Failed to update name:", error.localizedDescription)
        }

        isLoading = false
    }
}
