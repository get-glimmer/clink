import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Delete Account
                Button(role: .destructive) {
                    Task {
                        await authViewModel.deleteProfile()
                    }
                } label: {
                    Text("Delete Account")
                        .foregroundColor(.red)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }

                // Logout
                Button {
                    Task {
                        await authViewModel.logout()
                    }
                } label: {
                    Text("Logout")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Account Settings")
        }
    }
}
