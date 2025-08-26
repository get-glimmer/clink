import SwiftUI
import Supabase

enum Screen: Hashable {
    case otp(phoneNumber: String, isSignup: Bool)
    case finishSignup(phoneNumber: String?, email: String?, password: String?, userId: String? )
    case emailLogin
    case emailSignup
    case signupSuccess
}


struct LoginFlowView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VerifyIdentityView(path: $path).navigationDestination(for: Screen.self) { screen in
                switch screen {
                    case .otp(let number, let isSignup):
                        OTPView(phoneNumber: number, isSignup: isSignup, path: $path)
                            .environmentObject(authViewModel)
                    case .finishSignup(let number, let email, let password, let userId):
                        FinishSignupView(phoneNumber: number, email: email, password: password, userId: userId, path: $path)
                            .environmentObject(authViewModel)
                    case .emailLogin:
                            EmailLoginView(path: $path)
                                .environmentObject(authViewModel)
                    case .emailSignup:
                        EmailSignupView(path: $path)
                            .environmentObject(authViewModel)
                    // Not included in the flow yet.
                    case .signupSuccess:
                            SignupSuccessView()
                                .environmentObject(authViewModel)
                }
            }
        }
    }
}
