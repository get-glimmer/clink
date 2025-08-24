import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showSignup = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Login")
                    .font(.largeTitle)
                    .bold()

                TextField("Email", text: $email)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Login") {
                    Task {
                        authViewModel.email = email
                        authViewModel.password = password
                        await authViewModel.logIn()
                        if !authViewModel.isAuthenticated {
                            errorMessage = "Login failed"
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red)
                }

                Spacer()

                NavigationLink(destination: SignupView()) {
                    Text("Don’t have an account? Sign Up")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
}
