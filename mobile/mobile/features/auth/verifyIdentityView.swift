import SwiftUI
import Supabase
import AuthenticationServices
import GoogleSignIn

/**
 * The initial view for logging in or signing up.
 */
struct VerifyIdentityView: View {
    // MARK: - Environment and State

    /// The navigation path for programmatic navigation.
    @Binding var path: NavigationPath

    /// The authentication view model from the environment.
    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - Body

    var attributed: AttributedString {
        var terms = AttributedString("Terms of service")
        terms.underlineStyle = .single
        terms.foregroundColor = Color("Neutral-400")
        terms.link = URL(string: "https://clink.framer.website/legal-terms/terms-and-conditions")

        var privacy = AttributedString("Privacy Policy")
        privacy.underlineStyle = .single
        privacy.foregroundColor = Color("Neutral-400")
        privacy.link = URL(string: "https://clink.framer.website/legal-terms/privacy-policy")

        return terms + AttributedString(" and ") + privacy
    }

    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("clink")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .padding(.bottom, 293)

                // Social sign-on buttons
                VStack(spacing: 8) {
                    // Google → custom logo image in Assets
                    SSOButton(title: "Continue with Google",
                              color: Color("White"),
                              icon: "google") {
                        Task { await startSignInWithGoogle() }
                    }

                    // Apple → SF Symbol
                    SSOButton(title: "Continue with Apple",
                              color: Color("White"),
                              icon: "apple.logo") {
                        startSignInWithApple()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 43)

                VStack(spacing: 5) {
                    Text("By signing up, you agree to our")
                        .appFont(AppFont.captionXS)
                        .foregroundColor(Color("Neutral-400"))
                        .multilineTextAlignment(.center)

                    Text(attributed)
                        .appFont(AppFont.captionXS)
                        .foregroundColor(Color("Neutral-400"))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 15.85)
            }
        }
    }

    // MARK: - Private Methods

    /**
     * Starts the native Sign in with Apple flow.
     */
    private func startSignInWithApple() {
        let raw = AppleNonce.random()
        authViewModel.appleRawNonce = raw

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleNonce.sha256(raw)

        let delegate = AppleSignInDelegate(authViewModel: authViewModel, rawNonce: raw)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        AppleSignInDelegate.current = delegate   // retain until completion
        controller.performRequests()
    }

    /**
     * Starts the native Sign in with Google flow via the GoogleSignIn SDK and
     * forwards the resulting tokens to the auth view model.
     */
    @MainActor
    private func startSignInWithGoogle() async {
        guard let presenter = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else { return }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else { return }
            await authViewModel.signInWithGoogle(
                idToken: idToken,
                accessToken: result.user.accessToken.tokenString,
                fullName: result.user.profile?.name
            )
        } catch {
            // User cancelled or the flow failed.
            print("⚠️ GoogleSignIn SDK error: \(error)")
        }
    }
}

// MARK: - AppleSignInDelegate

/**
 * Handles the `ASAuthorizationController` callbacks for Sign in with Apple and
 * forwards the identity token to the auth view model.
 */
final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate,
                                 ASAuthorizationControllerPresentationContextProviding {
    /// Strong reference kept alive for the duration of the request.
    static var current: AppleSignInDelegate?

    private let authViewModel: AuthViewModel
    private let rawNonce: String

    init(authViewModel: AuthViewModel, rawNonce: String) {
        self.authViewModel = authViewModel
        self.rawNonce = rawNonce
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { AppleSignInDelegate.current = nil }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else { return }

        let fullName = credential.fullName
        Task { @MainActor in
            await authViewModel.signInWithApple(idToken: token, nonce: rawNonce, fullName: fullName)
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        AppleSignInDelegate.current = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}

// MARK: - SSOButton

/**
 * A reusable button for social sign-on options.
 */
struct SSOButton: View {
    var title: String
    var color: Color
    var icon: String      // Can be SF Symbol name or Asset name
    var iconColor: Color? // Optional override
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                if UIImage(named: icon) != nil {
                    // If the icon exists in Assets (e.g., google_logo)
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                } else {
                    // Otherwise treat it as an SF Symbol
                    Image(systemName: icon)
                        .foregroundColor(iconColor ?? .black)
                }
                Text(title)
                    .appFont(AppFont.labelL)
                    .foregroundColor(Color("Neutral-1000"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.white)
            .cornerRadius(8)
        }
    }
}


// MARK: - CountryPickerView

/**
 * A view for picking a country code.
 */
struct CountryPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCode: String
    @Binding var selectedFlag: String
    
    // Use image asset names instead of emoji
    let countries = [
        ("America_Flag", "+1"),
    ]
    
    var body: some View {
        NavigationStack {
            List(countries, id: \.1) { flagImage, code in
                HStack(spacing: 12) {
                    Image(flagImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 20)
                    Text(code)
                        .foregroundColor(.white)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCode = code
                    selectedFlag = flagImage
                    dismiss()
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


// MARK: - Previews

struct VerifyIdentityView_Previews: PreviewProvider {
    @State static var path = NavigationPath()
    
    static var previews: some View {
        NavigationStack {
            VerifyIdentityView(path: $path)
                .environmentObject(AuthViewModel())
        }
    }
}
