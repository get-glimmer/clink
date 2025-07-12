import SwiftUI

struct RootView: View {
    @State private var isAuthenticated = false
    
    init() {
        // Check for persisted userId and userName on launch
        if getUserId() != nil && getUserName() != nil {
            _isAuthenticated = State(initialValue: true)
        }
    }
    
    var body: some View {
        if isAuthenticated {
            AppRouter()
        } else {
            AuthView(isAuthenticated: $isAuthenticated)
        }
    }
}

#Preview {
    RootView()
} 