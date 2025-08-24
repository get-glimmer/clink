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
            }

            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .foregroundColor(.gray)
                    .font(.subheadline)

                HStack(spacing: 8) {
                    TextField("Enter name", text: $viewModel.name)
                        .padding()
                        .background(Color(.clear))
                        .cornerRadius(10)
                        .frame(height: 44)
                        .overlay( // use overlay for more flexible border with corner radius
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color("Neutral-600"), lineWidth: 1)
                        )

                    Button {
                        Task {
                            await viewModel.updateName(authViewModel: authViewModel)
                        }
                    } label: {
                        Text(viewModel.isLoading ? "Saving..." : "Confirm")
                            .foregroundColor(.white)
                            .frame(maxWidth: 80)
                            .frame(height: 44)
                            .background(Color("Neutral-800"))
                            .cornerRadius(10)
                    }
                    .disabled(viewModel.isLoading)
                }

            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
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
