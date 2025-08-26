import SwiftUI
import Supabase

struct SignupSuccessView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var navigateToApp = false

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
            
            // Hidden navigation link to AppRouter
            NavigationLink(
                destination: AppRouter()
                    .environmentObject(authViewModel),
                isActive: $navigateToApp,
                label: { EmptyView() }
            )
        }
        .padding()
        .navigationBarBackButtonHidden(true) // prevent going back
    }
}
