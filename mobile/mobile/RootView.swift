import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if !authViewModel.isAppReady {
                ProgressView()
            } else if authViewModel.isAuthenticated {
                if authViewModel.needsProfileSetup {
                    NavigationStack {
                        FinishSignupView(
                            phoneNumber: nil,
                            email: nil,
                            password: nil,
                            userId: nil,
                            isProfileCompletion: true,
                            path: .constant(NavigationPath())
                        )
                        .environmentObject(authViewModel)
                    }
                } else {
                    AppRouter()
                        .environmentObject(authViewModel)
                }
            } else {
                LoginFlowView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

