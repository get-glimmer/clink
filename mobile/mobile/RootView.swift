import SwiftUI

struct RootView: View {
    @State private var isAuthenticated = false
    var body: some View {
        if isAuthenticated {
            AppRouter()
        } else {
            AuthView(viewModel: AuthViewModel(), isAuthenticated: $isAuthenticated)
        }
    }
}

#Preview {
    RootView()
} 