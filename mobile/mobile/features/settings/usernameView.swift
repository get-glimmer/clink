import SwiftUI

struct UsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = UsernameViewModel()

    @State private var username: String = ""
    @State private var usernameConfirmed: Bool = false
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
            .padding(.top, 8)

            // Email
            if let email = authViewModel.profile?.email {
                Text(email)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .foregroundStyle(Color("Neutral-800"))
            }
            

            // Username input field and confirmation
            VStack(alignment: .leading, spacing: 4) {
                Text("Username")
                    .padding(.leading, 10)
                    .font(.subheadline)
                    .foregroundColor(Color("Neutral-300"))

                HStack(spacing: 8) {
                    TextField("Username", text: $username)
                        .padding()
                        .background(Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                        .cornerRadius(12)
                        .onChange(of: username) {
                            usernameConfirmed = false
                            usernameStatus = nil
                        }

                    Button {
                        Task {
                            if await authViewModel.checkUsername(username) {
                                do {
                                    try await authViewModel.updateUsername(username)
                                    usernameConfirmed = true
                                    usernameStatus = "Username updated successfully."
                                    usernameStatusColor = .green

                                    // ✅ Auto-dismiss after short delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        dismiss()
                                    }

                                } catch {
                                    usernameStatus = "Failed to update username."
                                    usernameStatusColor = .red
                                    print("❌ Error updating username:", error.localizedDescription)
                                }
                            } else {
                                usernameStatus = "The username is already in use."
                                usernameStatusColor = .red
                                usernameConfirmed = false
                            }
                        }
                    } label: {
                        Text("Confirm")
                            .frame(width: 100, height: 55)
                            .foregroundColor(username.isEmpty ? .white : Color("Neutral-900"))
                            .padding(.horizontal, 16)
                            .background(username.isEmpty ? Color("Neutral-800") : Color("Green-300"))
                            .cornerRadius(12)
                    }
                    .disabled(username.isEmpty)
                }
                .frame(height: 55)

                if let status = usernameStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(usernameStatusColor)
                        .padding(.leading, 4)
                }
            }
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
        .padding(.horizontal)
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
