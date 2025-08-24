//import SwiftUI
//
//struct AuthView: View {
//    @Binding var isAuthenticated: Bool
//    @State private var selectedTab = 0
//
//    var body: some View {
//        VStack {
//            Picker("Auth", selection: $selectedTab) {
//                Text("Login").tag(0)
//                Text("Signup").tag(1)
//            }
//            .pickerStyle(SegmentedPickerStyle())
//            .padding()
//
//            if selectedTab == 0 {
//                LoginView(isAuthenticated: $isAuthenticated)
//            } else {
//                SignupView(isAuthenticated: $isAuthenticated)
//            }
//        }
//        .padding()
//    }
//}
