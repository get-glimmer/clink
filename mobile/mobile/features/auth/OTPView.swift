import SwiftUI
import Supabase

struct OTPView: View {
    let phoneNumber: String
    let isSignup: Bool
    @Binding var path: NavigationPath
    @State private var code: String = ""
    @State private var isLoading = false
    @State private var timeRemaining = 30
    @EnvironmentObject var authViewModel: AuthViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Title
            Text("Verification Code")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            
            Text("Enter the code sent to \(phoneNumber)")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(Color("White"))
            
            // MARK: - OTP Boxes
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(code.count > index ? Color("Green-400") : Color.clear)
                            )
                            .frame(width: 50, height: 80)
                        
                        Text(code.count > index ? String(code[code.index(code.startIndex, offsetBy: index)]) : "")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(Color("Neutral-1000"))
                    }
                }
            }
            // Hidden TextField
            .background(
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isTextFieldFocused)
                    .frame(width: 0, height: 0)
                    .opacity(0.01)
                    .onChange(of: code) { newValue in
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
            
            // MARK: - Resend Timer
            Text(timeRemaining > 0 ? "Resend code in \(timeRemaining)" : "Resend Code")
                .foregroundColor(timeRemaining > 0 ? .gray : .blue)
                .onTapGesture {
                    if timeRemaining == 0 {
                        resendCode()
                    }
                }
            
            Spacer()
        }
        .padding()
        .onAppear {
            startTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    // MARK: - Verify OTP
    private func verifyOTP() async {
        guard !isLoading, let client = SupabaseClientManager.shared.client else { return }
        isLoading = true
        
        do {
            try await client.auth.verifyOTP(phone: phoneNumber, token: code, type: .sms)
            print("OTP verified for \(phoneNumber)")
            
            let session = try await client.auth.session   // this should exist after OTP
            let userId = session.user.id.uuidString
            
            await MainActor.run {
                if isSignup {
                    path.append(Screen.finishSignup(phoneNumber: phoneNumber, email: nil, userId: userId))
                } else {
                    authViewModel.isAuthenticated = true
                }
            }
        } catch {
            print("OTP verification failed:", error.localizedDescription)
            await MainActor.run {
                code = ""   // RESET input when OTP fails
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Timer
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
    
    private func resendCode() {
        guard let client = SupabaseClientManager.shared.client else { return }
        
        Task {
            do {
                try await client.auth.signInWithOTP(
                    phone: phoneNumber
                )
                print("OTP resent to \(phoneNumber)")
                
                await MainActor.run {
                    startTimer()
                }
            } catch {
                print("Failed to resend OTP:", error.localizedDescription)
            }
        }
    }

}

#Preview {
    OTPView(
        phoneNumber: "+821012345678",
        isSignup: true,
        path: .constant(NavigationPath())
    )
    .environmentObject(AuthViewModel())
}
