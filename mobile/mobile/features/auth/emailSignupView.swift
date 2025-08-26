import SwiftUI

struct EmailSignupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var path: NavigationPath
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var emailError: String? = nil
    
    var body: some View {
        VStack {
            ScrollView {
                TopNavBar(title: "Sign up") {
                    dismiss()
                }
                
                VStack(alignment: .leading, spacing: 35) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.leading, 5)
                            .padding(.top, 10)
                        
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .padding()
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                            .onChange(of: email) {
                                emailError = nil
                            }

                        if let error = emailError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 5)
                        }
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.leading, 5)
                        ZStack(alignment: .trailing) {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .padding()
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(Color("Neutral-200"))
                                    .padding()
                            }
                        }
                        
                        // Password Requirements (Left-aligned)
                        let reqs = authViewModel.passwordRequirements(password)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your password must include the following")
                                .font(.subheadline)
                                .foregroundColor(Color("Neutral-100"))
                                .padding(.bottom)
                                .padding(.leading, 5)
                            
                            passwordRequirementRow("Minimum 8 characters", check: reqs.min8)
                            passwordRequirementRow("At least one number", check: reqs.number)
                            passwordRequirementRow("Upper & lowercase letters", check: reqs.upperLower)
                        }
                        .padding(.leading, 5)
                    }
                }
                .padding()
            }
            
            // Continue Button
            Button {
                guard authViewModel.validatePassword(password) else { return }
                guard let client = SupabaseClientManager.shared.client else { return }

                Task {
                    isLoading = true

                    let inUse = await authViewModel.checkEmailInUse(email)

                    await MainActor.run {
                        if inUse {
                            emailError = "Email is already in use"
                        } else {
                            emailError = nil
                        }
                    }

                    if !inUse {
                        await MainActor.run {
                            path.append(
                                Screen.finishSignup(
                                    phoneNumber: nil,
                                    email: email,
                                    password: password,
                                    userId: nil
                                )
                            )
                        }
                    }

                    isLoading = false
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(!email.isEmpty && !password.isEmpty && authViewModel.validatePassword(password) ? Color("Green-300") : Color("Neutral-800"))
                    .foregroundColor(!email.isEmpty && !password.isEmpty && authViewModel.validatePassword(password) ? Color("Neutral-900") : Color("Neutral-600"))
                    .cornerRadius(12)
                    .padding()
            }
            .disabled(email.isEmpty || password.isEmpty || !authViewModel.validatePassword(password))
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true) // hide default "Back" text
    }
    
    private func passwordRequirementRow(_ text: String, check: Bool) -> some View {
        HStack {
            Text(check ? "✅" : "☑️")
            Text(text)
                .foregroundColor(.white)
                .font(.subheadline)
        }
    }
}

struct EmailSignupView_Previews: PreviewProvider {
    @State static var path = NavigationPath()
    
    static var previews: some View {
        NavigationStack(path: $path) {
            EmailSignupView(path: $path)
                .environmentObject(AuthViewModel())
        }
    }
}
