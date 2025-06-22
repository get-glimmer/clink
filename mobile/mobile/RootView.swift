import SwiftUI

struct RootView: View {
    @State private var isAuthenticated = false
    var body: some View {
        if isAuthenticated {
            AppRouter()
        } else {
            authView(isAuthenticated: $isAuthenticated)
        }
    }
}

#Preview {
    RootView()
} 