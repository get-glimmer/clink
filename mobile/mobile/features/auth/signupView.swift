import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Sign Up")
                .font(.largeTitle)
                .bold()

            TextField("Email", text: $email)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Sign Up") {
                Task {
                    authViewModel.email = email
                    authViewModel.password = password
                    await authViewModel.signUp()
                    if !authViewModel.isAuthenticated {
                        errorMessage = "Sign up failed"
                    }
                }
            }
            .buttonStyle(.borderedProminent)

            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundColor(.red)
            }
        }
        .padding()
    }
}
