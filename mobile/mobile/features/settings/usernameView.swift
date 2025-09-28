import SwiftUI

struct UsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = UsernameViewModel()

    @State private var usernameStatus: String?
    @State private var usernameStatusColor: Color = .white
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    ZStack {
                        Circle()
                            .fill(Color("Neutral-900"))
                            .frame(width: 40, height: 40)
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color("Neutral-400"))
                            .frame(width: 12, height: 12)
                    }
                }
                Spacer()
                Text("My Account")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Circle()
                    .frame(width: 40, height: 40)
                    .opacity(0)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Email
            if let email = authViewModel.profile?.email {
                Text(email)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .foregroundStyle(Color("Neutral-800"))
            }
            

            // Username field
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .foregroundColor(Color("Neutral-300"))
                    .font(.subheadline)

                HStack(spacing: 8) {
                    TextField("Enter username", text: $viewModel.name)
                        .padding()
                        .background(Color.clear)
                        .cornerRadius(10)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color("Neutral-600"), lineWidth: 1)
                        )

                    Button {
                        Task {
                            await confirmAndSaveUsername()
                        }
                    } label: {
                        Text(isSaving ? "Saving..." : "Confirm")
                            .foregroundColor(.white)
                            .frame(width: 100, height: 55)
                            .frame(height: 44)
                            .background(Color("Neutral-800"))
                            .cornerRadius(10)
                    }
                    .disabled(isSaving || viewModel.name.isEmpty)
                }

                if let status = usernameStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(usernameStatusColor)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task {
            if authViewModel.profile == nil {
                await authViewModel.loadProfile()
            }
            viewModel.name = authViewModel.profile?.name ?? ""
        }
    }

    private func confirmAndSaveUsername() async {
        guard !viewModel.name.isEmpty else { return }
        isSaving = true

        let available = await authViewModel.checkUsername(viewModel.name)
        if available {
            // ✅ Save
            await viewModel.updateName(authViewModel: authViewModel)
            await MainActor.run {
                dismiss()
            }
        } else {
            // ❌ Not valid
            await MainActor.run {
                usernameStatus = "This username is already in use."
                usernameStatusColor = .red
            }
        }
        isSaving = false
    }
}

struct UsernameView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UsernameView()
                .environmentObject(AuthViewModel()) // Provide a sample AuthViewModel
                .preferredColorScheme(.dark)        // Optional: show dark mode
        }
    }
}
