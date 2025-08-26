import SwiftUI

struct EmailSignupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var path: NavigationPath
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sign up")
                .font(.title2)
                .bold()
                .padding(.top, 20)
            
            // Email Field
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray))
            
            // Password Field with Eye Button
            ZStack(alignment: .trailing) {
                Group {
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray))
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            // Password Policy Checks
            let reqs = authViewModel.passwordRequirements(password)

            VStack(alignment: .leading, spacing: 5) {
                Text("Your password must include the following:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                passwordRequirementRow("Minimum 8 characters", check: reqs.min8)
                passwordRequirementRow("At least one number", check: reqs.number)
                passwordRequirementRow("Upper & lowercase letters", check: reqs.upperLower)
            }

            // Sign Up Button
            Button {
                // Only go to FinishSignupView if email/password are valid
                guard authViewModel.validatePassword(password) else { return }
                guard let client = SupabaseClientManager.shared.client else { return }
                Task {
                    do {
                        let result = try await client.auth.signUp(email: email, password: password)
                        let userId = result.user.id.uuidString
                        await MainActor.run {
                            path.append(Screen.finishSignup(phoneNumber: nil, email: email, userId: userId))
                        }
                    } catch {
                        print("❌ Email signup failed:", error.localizedDescription)
                    }
                    }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(!email.isEmpty && !password.isEmpty && authViewModel.validatePassword(password) ? Color("Green-300") : Color.gray)
                    .foregroundColor(.black)
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty || password.isEmpty || !authViewModel.validatePassword(password))
        }
        .padding()
    }
    
    private func passwordRequirementRow(_ text: String, check: Bool) -> some View {
        HStack {
            Text(check ? "✅" : "☑️")
            Text(text)
                .foregroundColor(check ? .green : .gray)
                .font(.subheadline)
        }
    }
}
