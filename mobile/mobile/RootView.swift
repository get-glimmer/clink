import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if !authViewModel.isAppReady {
                // Full-screen loading view
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView("Loading…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                }
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

