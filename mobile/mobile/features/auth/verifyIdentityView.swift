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

    /// The user's phone number.
    @State private var phoneNumber: String = ""

    /// The flag of the selected country.
    @State private var selectedCountryFlag: String = "America_Flag"

    /// The code of the selected country.
    @State private var selectedCountryCode: String = "+1"

    /// A boolean to indicate if a network request is in progress.
    @State private var isLoading = false

    /// A boolean to control the visibility of the country picker.
    @State private var showCountryPicker = false

    /// The authentication view model from the environment.
    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - Body

    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()
            
            VStack{
                VStack {
                    VStack {
                        TopNavBar(title: "Log in or Sign up")
                        
                        Text("Phone number")
                            .appFont(AppFont.labelL)
                            .foregroundColor(Color("White"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 34)
                            .padding(.leading, 7)
                            .padding(.bottom, 12)
                        
                        // Country picker and phone number input
                        HStack() {
                            Button {
                                showCountryPicker = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(selectedCountryFlag)
                                        .appFont(AppFont.title1)

                                    Image("down_arrow")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                    Spacer()
                                }
                                .frame(width: 75, height: 49)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .inset(by: 0.35)
                                        .stroke(Color("Neutral-600"), lineWidth: 0.7)
                                )
                            }
                            
                            TextField(
                                text: $phoneNumber,
                                prompt: Text("Phone number")
                                    .foregroundColor(Color("Neutral-600"))
                            ) {
                                EmptyView()
                            }
                            .padding(.leading, 11)
                            .appFont(AppFont.body1)
                            .keyboardType(.phonePad)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .inset(by: 0.35)
                                    .stroke(Color("Neutral-600"), lineWidth: 0.7)
                            )
                            .onChange(of: phoneNumber) { _, newValue in
                                let sanitized = newValue.filter { "0123456789".contains($0) }
                                if sanitized != newValue { phoneNumber = sanitized }
                            }
                        }
                        .padding(.bottom, 12)
                        
                        Text("We’ll call or text to confirm your number. Standard message and data rates apply.")
                            .foregroundColor(Color("Neutral-400"))
                            .frame(maxWidth: .infinity, alignment: .leading)
//                            .frame(maxWidth: .infinity)
                            .appFont(AppFont.captionXS)
                            .padding(.bottom, 24)
                            .padding(.leading, 8)   // 이렇게 되면 완벽히 center 아님
                        
                        // Continue button
                        Button {
                            Task { await sendOTP() }
                        } label: {
                            Text("Continue")
                                .appFont(AppFont.buttonL)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(phoneNumber.isEmpty ? Color("Neutral-800") : Color("Green-300"))
                                .foregroundColor(phoneNumber.isEmpty ? Color("Neutral-600") : Color("Neutral-900"))
                                .cornerRadius(8)
                        }
                        .disabled(phoneNumber.isEmpty || isLoading)
                        .cornerRadius(8)
                        .padding(.bottom, 48)
                        
                        HStack(alignment: .center, spacing: 24) {
                            // Divider
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(width: 146, height: 0.5)
                                .background(Color("Neutral-600"))
                            Text("Or")
                                .appFont(AppFont.captionM)
                                .foregroundColor(Color("Neutral-400"))
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(width: 146, height: 0.5)
                                .background(Color("Neutral-600"))
                        }
                        .padding(0)
                        .frame(width: 361, alignment: .center)
                        .padding(.bottom, 48)
                        
                        // Social sign-on buttons
                        VStack(spacing: 12) {
                            // Google → custom logo image in Assets
                            SSOButton(title: "Continue with Google",
                                      color: Color("White"),
                                      icon: "google") {
                                Task { await startSignInWithGoogle() }
                            }

                            // Apple → still SF Symbol
                            SSOButton(title: "Continue with Apple",
                                      color: Color("White"),
                                      icon: "apple.logo") {
                                startSignInWithApple()
                            }
                            
                            // Email → SF Symbol with black color
                            SSOButton(title: "Continue with Email",
                                      color: Color("White"),
                                      icon: "email") {
                                path.append(Screen.emailLogin)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .sheet(isPresented: $showCountryPicker) {
                        CountryPickerView(selectedCode: $selectedCountryCode, selectedFlag: $selectedCountryFlag)
                    }
                }
                var attributed: AttributedString {
                    var terms = AttributedString("Terms of service")
                    terms.underlineStyle = .single
                    
                    var privacy = AttributedString("Privacy Policy")
                    privacy.underlineStyle = .single
                    
                    return terms + AttributedString(" and ") + privacy
                }
                
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
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .dismissKeyboardOnTap()
    }

    // MARK: - Private Methods

    /**
     * Sends an OTP to the user's phone number.
     */
    private func sendOTP() async {
        guard let client = SupabaseClientManager.shared.client else { return }
        isLoading = true
        let fullPhone = selectedCountryCode + phoneNumber

        do {
            try await client.auth.signInWithOTP(phone: fullPhone)

            let users: [Profile] = try await client
                .from("profiles")
                .select()
                .eq("phoneNumber", value: fullPhone)
                .execute()
                .value

            if users.isEmpty {
                path.append(Screen.otp(phoneNumber: fullPhone, isSignup: true))
            } else {
                path.append(Screen.otp(phoneNumber: fullPhone, isSignup: false))
            }

        } catch {
        }
        isLoading = false
    }

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
