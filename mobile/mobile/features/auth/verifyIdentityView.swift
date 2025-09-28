import SwiftUI
import Supabase

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
    @State private var selectedCountryFlag: String = "🇺🇸"

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
        VStack(spacing: 24) {
            Text("Log in or Sign up")
                .appFont(AppFont.title2)
                .bold()
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
            
            Text("Phone number")
                .foregroundColor(Color("White"))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Country picker and phone number input
            HStack(spacing: 8) {
                Button {
                    showCountryPicker = true
                } label: {
                    HStack {
                        Text(selectedCountryFlag)
                        Image(systemName: "chevron.down")
                            .foregroundColor(Color("Neutral-300"))
                            .font(.system(size: 12))
                    }
                    .frame(height: 50)
                    .frame(minWidth: 60)
                    .padding(.horizontal, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("Neutral-600"), lineWidth: 1)
                    )
                }

                TextField(
                    text: $phoneNumber,
                    prompt: Text("Phone number")
                        .foregroundColor(Color("Neutral-600")) // 👈 placeholder color
                ) {
                    EmptyView() // no label
                }
                .appFont(AppFont.body1)
                .keyboardType(.phonePad)
                .foregroundColor(.white) // 👈 user-entered text color
                .padding()
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("Neutral-600"), lineWidth: 1)
                )
                .onChange(of: phoneNumber) { _, newValue in
                    let sanitized = newValue.filter { "0123456789".contains($0) }
                    if sanitized != newValue { phoneNumber = sanitized }
                }

            }

            Text("We’ll call or text to confirm your number. Standard message and data rates apply.")
                .foregroundColor(Color("Neutral-400"))
                .appFont(AppFont.captionXS)
            
            // Continue button
            Button {
                Task { await sendOTP() }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(phoneNumber.isEmpty ? Color("Neutral-800") : Color("Green-300"))
                    .foregroundColor(phoneNumber.isEmpty ? Color("Neutral-600") : Color("Neutral-900"))
                    .cornerRadius(12)
            }
            .disabled(phoneNumber.isEmpty || isLoading)

            // Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color("Neutral-600"))
                Text("Or")
                    .foregroundColor(Color("Neutral-400"))
                    .padding(.horizontal)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color("Neutral-600"))
            }
            .padding(.vertical, 10)

            // Social sign-on buttons
            VStack(spacing: 12) {
                // Google → custom logo image in Assets
                SSOButton(title: "Continue with Google",
                          color: Color("White"),
                          icon: "google") {
                    print("Google pressed")
                }

                // Apple → still SF Symbol
                SSOButton(title: "Continue with Apple",
                          color: Color("White"),
                          icon: "apple.logo") {
                    print("Apple pressed")
                }

                // Email → SF Symbol with black color
                SSOButton(title: "Continue with Email",
                          color: Color("White"),
                          icon: "email") {
                    path.append(Screen.emailLogin)
                }
            }



            Spacer()
            
            VStack(spacing: 5) {
                Text("By signing up, you agree to our")
                    .foregroundColor(Color("Neutral-400"))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Text("Terms of service and Privacy Policy")
                    .foregroundColor(Color("Neutral-400"))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 5)
            }
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selectedCode: $selectedCountryCode, selectedFlag: $selectedCountryFlag)
        }
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
            print("OTP sent to \(fullPhone)")

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
            print("Error sending OTP:", error.localizedDescription)
        }
        isLoading = false
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
            HStack {
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
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color)
            .foregroundColor(.black) // text color
            .cornerRadius(12)
        }
    }
}


// MARK: - CountryPickerView

/**
 * A view for picking a country code.
 */
struct CountryPickerView: View {
    // MARK: - Environment and Bindings

    /// The presentation mode of the view.
    @Environment(\.dismiss) var dismiss

    /// The selected country code.
    @Binding var selectedCode: String

    /// The flag of the selected country.
    @Binding var selectedFlag: String

    // MARK: - Properties

    /// A list of countries with their flags and codes.
    let countries = [
        ("🇰🇷", "+82"),
        ("🇺🇸", "+1"),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List(countries, id: \.1) { flag, code in
                HStack {
                    Text(flag)
                    Text(code)
                    Spacer()
                }
                .padding()
                .background(Color.clear)
                .foregroundColor(.white)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCode = code
                    selectedFlag = flag
                    dismiss()
                }
            }
            .navigationTitle("Select Country")
            .background(Color.black.ignoresSafeArea())
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
