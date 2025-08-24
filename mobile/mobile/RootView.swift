import SwiftUI

struct RootView: View {
    @State private var isAuthenticated = false
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Check for persisted userId and userName on launch
        if getUserId() != nil && getUserName() != nil {
            _isAuthenticated = State(initialValue: true)
        }
    }

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
