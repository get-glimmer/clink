import SwiftUI
import Supabase

/**
 * A view to be displayed after a user has successfully signed up.
 */
struct SignupSuccessView: View {
    // MARK: - Environment and State

    /// The authentication view model from the environment.
    @EnvironmentObject var authViewModel: AuthViewModel

    /// A boolean to control navigation to the main app.
    @State private var navigateToApp = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.green)
            
            Text("You're signed up!")
                .font(.title2)
                .bold()
            
            Text("Your account has been successfully created.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Button to navigate to the main app
            Button {
                navigateToApp = true
            } label: {
                Text("Login")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            
            // Hidden navigation link for programmatic navigation
            NavigationLink(
                destination: AppRouter()
                    .environmentObject(authViewModel),
                isActive: $navigateToApp,
                label: { EmptyView() }
            )
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
}
