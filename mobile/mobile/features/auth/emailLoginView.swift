import SwiftUI

struct EmailLoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var path: NavigationPath
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        // custom top nav
        TopNavBar(title: "Log in") {
            dismiss()
        }
        
        VStack (spacing: 35) {
            // Email Field
            VStack(alignment: .leading, spacing: 5) {
                Text("Email")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.leading, 5)
                    .padding(.top, 10)
                
                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 5) {
                Text("Password")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.leading, 5)
                
                SecureField("Enter your password", text: $password)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                
                // Forgot password? right below password
                Button {
                    Task {
                        let success = await authViewModel.resetPassword(for: email)
                        alertMessage = success
                            ? "Password reset email sent to \(email)"
                            : "Put valid email on the email section"
                        showAlert = true
                    }
                } label: {
                    Text("Forgot password?")
                        .underline(true, color: .white)
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 5)
                        .padding(.leading, 5)
                }
            }
            
            // Error message below password
            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 5)
            }
            
            Spacer()
            
            // Don't have an account? right above Continue button
            HStack {
                Text("Don't have an account?")
                    .foregroundColor(.gray)
                
                Button {
                    Task {
                        path.append(Screen.emailSignup)
                    }
                } label: {
                    Text("Sign up")
                        .underline(true, color: .white)
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            // Continue Button
            Button {
                Task {
                    isLoading = true
                    authViewModel.email = email
                    authViewModel.password = password
                    await authViewModel.logIn()
                    isLoading = false
                }
            } label: {
                Text(isLoading ? "Logging in..." : "Continue")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(!email.isEmpty && !password.isEmpty ? Color("Green-300") : Color("Neutral-800"))
                    .foregroundColor(!email.isEmpty && !password.isEmpty ? Color("Neutral-900") : Color("Neutral-600"))
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
        }
        .padding()
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
    }
}
