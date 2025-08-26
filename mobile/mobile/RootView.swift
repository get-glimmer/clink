import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if !authViewModel.isAppReady {
                ProgressView()
            } else if authViewModel.isAuthenticated {
                AppRouter()
                    .environmentObject(authViewModel)
            } else {
                LoginFlowView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

