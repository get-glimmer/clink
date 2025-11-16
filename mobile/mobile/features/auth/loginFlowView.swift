import SwiftUI
import Supabase

/**
 * An enumeration of the screens in the login and sign-up flow.
 */
enum Screen: Hashable {
    /// The OTP verification screen.
    case otp(phoneNumber: String, isSignup: Bool)

    /// The screen for finishing the sign-up process.
    case finishSignup(phoneNumber: String?, email: String?, password: String?, userId: String?)

    /// The email login screen.
    case emailLogin

    /// The email sign-up screen.
    case emailSignup

    /// The sign-up success screen.
    case signupSuccess
}

/**
 * The main view for the login and sign-up flow, managing navigation between screens.
 */
struct LoginFlowView: View {
    // MARK: - Environment and State

    /// The authentication view model from the environment.
    @EnvironmentObject var authViewModel: AuthViewModel

    /// The navigation path for programmatic navigation.
    @State private var path = NavigationPath()

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            VerifyIdentityView(path: $path)
                .navigationDestination(for: Screen.self) { screen in
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
                    case .signupSuccess:
                        SignupSuccessView()
                            .environmentObject(authViewModel)
                    }
                }
                .onChange(of: authViewModel.shouldResetLoginFlow) { shouldReset in
                    print("[LoginFlowView] shouldResetLoginFlow changed:", shouldReset)
                    if shouldReset {
                        path = NavigationPath()
                        print("[LoginFlowView] path reset")
                        authViewModel.shouldResetLoginFlow = false
                    }
                }

        }
    }
}
