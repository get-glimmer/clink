import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isCheckingAuth {
                ProgressView("Loading...") // Show while checking
            } else if authViewModel.isAuthenticated {
                AppRouter()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

