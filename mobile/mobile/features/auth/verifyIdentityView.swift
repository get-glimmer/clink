import SwiftUI
import Supabase

// MARK: - Main View
struct VerifyIdentityView: View {
    @Binding var path: NavigationPath
    @State private var phoneNumber: String = ""
    @State private var selectedCountryFlag: String = "🇺🇸"
    @State private var selectedCountryCode: String = "+1"
    @State private var isLoading = false
    @State private var showCountryPicker = false
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Log in or Sign up")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
            
            // Phone number label
            Text("Phone number")
                .foregroundColor(Color("White"))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Country picker + phone input
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
                    .frame(height: 50) // match TextField height
                    .frame(minWidth: 60)
                    .padding(.horizontal, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }

                TextField("Enter your phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .foregroundColor(.white)
                    .padding()
                    .frame(height: 50) // same as picker
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .onChange(of: phoneNumber) { old, newValue in
                        let sanitized = newValue.replacingOccurrences(of: " ", with: "")
                                                .replacingOccurrences(of: "-", with: "")
                        if sanitized != newValue { phoneNumber = sanitized }
                    }
            }

            // Random gray texts
            Text("We’ll call or text to confirm your number. Standard message and data rates apply.")
                .foregroundColor(.gray)
                .font(.footnote)
            

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

            // Divider with "Or"
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color("Neutral-600"))
                Text("Or")
                    .foregroundColor(Color("Neutral-400"))
                    .padding(.horizontal)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 10)

            // SSO Buttons
            VStack(spacing: 12) {
                SSOButton(title: "Continue with Google", color: Color("White"), icon: "globe") {
                    print("Google pressed") // <- action closure
                }

                SSOButton(title: "Continue with Apple", color: Color("White"), icon: "applelogo") {
                    print("Apple pressed")
                }

                SSOButton(title: "Continue with Email", color: Color("White"), icon: "envelope") {
                    path.append(Screen.emailLogin) // <- navigate to email login
                }
            }

            Spacer()
            
            VStack(spacing: 5) {
                // Bottom random text
                Text("By signing up, you agree to our")
                    .foregroundColor(.gray)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Text("Terms of service and Privacy Policy")
                    .foregroundColor(.gray)
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

    // MARK: - OTP Sending
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
                .value ?? []

            await MainActor.run {
                if users.isEmpty {
                    path.append(Screen.otp(phoneNumber: fullPhone, isSignup: true))
                } else {
                    path.append(Screen.otp(phoneNumber: fullPhone, isSignup: false))
                }
            }

        } catch {
            print("Error sending OTP:", error.localizedDescription)
        }
        isLoading = false
    }
}

// MARK: - SSO Button Component
struct SSOButton: View {
    var title: String
    var color: Color
    var icon: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color)
            .foregroundColor(.black)
            .cornerRadius(12)
        }
    }
}


// MARK: - Country Picker
struct CountryPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCode: String
    @Binding var selectedFlag: String

    let countries = [
        ("🇰🇷", "+82"),
        ("🇺🇸", "+1"),
    ]

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

// MARK: - Preview
struct VerifyIdentityView_Previews: PreviewProvider {
    @State static var path = NavigationPath()
    
    static var previews: some View {
        NavigationStack {
            VerifyIdentityView(path: $path)
                .environmentObject(AuthViewModel())
        }
    }
}
