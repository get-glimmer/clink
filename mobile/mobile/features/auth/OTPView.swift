import SwiftUI
import Supabase

/**
 * A view for users to enter a one-time password (OTP) for verification.
 */
struct OTPView: View {
    // MARK: - Properties

    /// The phone number to which the OTP was sent.
    let phoneNumber: String

    /// A boolean indicating if this is part of the sign-up process.
    let isSignup: Bool

    // MARK: - Environment and State

    /// The navigation path for programmatic navigation.
    @Binding var path: NavigationPath

    /// The OTP code entered by the user.
    @State private var code: String = ""

    /// A boolean to indicate if a network request is in progress.
    @State private var isLoading = false

    /// The remaining time for the user to enter the OTP before they can request a new one.
    @State private var timeRemaining = 30
    
    @State private var errorMessage: String? = nil

    /// The authentication view model from the environment.
    @EnvironmentObject var authViewModel: AuthViewModel

    /// A focus state to control the visibility of the keyboard.
    @FocusState private var isTextFieldFocused: Bool

    /// The presentation mode of the view.
    @Environment(\.dismiss) var dismiss

    // MARK: - Body

    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()
            
            
            VStack {
                TopNavBar(title: "Verification Code") {
                    dismiss()
                }
                .padding(.leading, 16)
                
                VStack {
                    Text("Enter the code we texted you \non \(phoneNumber)")
                        .padding(.top, 82)
                        .multilineTextAlignment(.center)
                        .appFont(AppFont.body1)
                        .foregroundColor(Color("White"))
                    
                    // OTP input boxes
                    HStack(spacing: 8) {
                        ForEach(0..<6, id: \.self) { index in
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("Neutral-600"), lineWidth: 0.7)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .inset(by: 0.35)
                                            .fill(code.count > index ? Color("Green-400") : Color.clear)
                                    )
                                    .frame(height: 108)
                                    .frame(maxWidth: .infinity)
                                
                                if code.count > index {
                                    Text(String(code[code.index(code.startIndex, offsetBy: index)]))
                                        .appFont(AppFont.headlineL)
                                        .foregroundColor(Color("Neutral-1000"))
                                }
                            }
                        }
                    }
                    .padding(.top, 34)
                    // Hidden text field for OTP input
                    .background(
                        TextField("", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($isTextFieldFocused)
                            .frame(width: 0, height: 0)
                            .opacity(0.01)
                            .onChange(of: code) { newValue, oldValue in
                                if newValue.count > 6 {
                                    code = String(newValue.prefix(6))
                                }
                                if code.count == 6 {
                                    Task { await verifyOTP() }
                                }
                            }
                    )
                    .onTapGesture {
                        isTextFieldFocused = true
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(Color("Red-300"))
                            .appFont(AppFont.captionS)
                            .padding(.top, 10)
                    }
                    
                    
                    // Resend code timer
                    Text(timeRemaining > 0 ? "Resend code in \(timeRemaining)" : "Resend Code")
                        .padding(.top, 14)
                        .appFont(AppFont.captionS)
                        .foregroundColor(timeRemaining > 0 ? Color("Neutral-400") : Color("Green-300"))
                        .onTapGesture {
                            if timeRemaining == 0 {
                                resendCode()
                            }
                        }
                    
                    Spacer()
                }
                .padding(.horizontal, 29)
            }
            .background(Color("Neutral-1000"))
            
            .onAppear {
                startTimer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
        .dismissKeyboardOnTap()
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Private Methods

    /**
     * Verifies the entered OTP.
     */
    private func verifyOTP() async {
        guard !isLoading, let client = SupabaseClientManager.shared.client else { return }
        isLoading = true
        
        do {
            try await client.auth.verifyOTP(phone: phoneNumber, token: code, type: .sms)
            print("OTP verified for \(phoneNumber)")
            
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            
            if isSignup {
                path.append(
                    Screen.finishSignup(
                        phoneNumber: phoneNumber,
                        email: nil,
                        password: nil,
                        userId: userId
                    )
                )
            } else {
                authViewModel.isAuthenticated = true
            }
        } catch {
            errorMessage = "Invalid verification code. Please try again."  // 👈 set message
            code = "" // Reset input on failure
        }
        
        isLoading = false
    }

    /**
     * Starts the countdown timer for resending the OTP.
     */
    private func startTimer() {
        timeRemaining = 30
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    /**
     * Resends the OTP to the user's phone number.
     */
    private func resendCode() {
        guard let client = SupabaseClientManager.shared.client else { return }
        
        Task {
            do {
                try await client.auth.signInWithOTP(phone: phoneNumber)
                print("OTP resent to \(phoneNumber)")
                startTimer()
            } catch {
                print("Failed to resend OTP:", error.localizedDescription)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    OTPView(
        phoneNumber: "+821012345678",
        isSignup: true,
        path: .constant(NavigationPath())
    )
    .environmentObject(AuthViewModel())
}
