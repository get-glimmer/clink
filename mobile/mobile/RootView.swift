import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()

        var body: some View {
            if authViewModel.isAuthenticated {
                AppRouter()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
}
