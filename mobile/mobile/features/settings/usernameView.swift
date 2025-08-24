import SwiftUI

struct UsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = UsernameViewModel()

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .semibold))
                }
                Spacer()
                Text("My Account")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.left").opacity(0)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Email
            if let email = authViewModel.profile?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .foregroundColor(.gray)
                    .font(.subheadline)

                HStack {
                    TextField("Enter name", text: $viewModel.name)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    Button {
                        Task {
                            await viewModel.updateName(authViewModel: authViewModel)
                        }
                    } label: {
                        Text(viewModel.isLoading ? "Saving..." : "Confirm")
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(viewModel.isLoading ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            // Load profile if not already loaded
            if authViewModel.profile == nil {
                await authViewModel.loadProfile()
            }

            // Once loaded, set the TextField
            viewModel.name = authViewModel.profile?.name ?? ""
        }
        .onChange(of: authViewModel.profile) {
            viewModel.name = authViewModel.profile?.name ?? ""
        }
    }
}
