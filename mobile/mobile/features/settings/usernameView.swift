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
        TopNavBar(title: "My Account") {
            dismiss()
        }
        
        VStack {
            // Email
            if let email = authViewModel.profile?.email {
                Text(email)
                    .padding(.leading, 10)
                    .padding(.top, 24)
                    .padding(.bottom, 10)
                    .appFont(AppFont.labelL)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .foregroundStyle(Color("Neutral-800"))
            }
            

            // Username input field and confirmation
            VStack(alignment: .leading) {
                Text("Username")
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    .padding(.leading, 11)
                    .appFont(AppFont.labelS)
                    .foregroundColor(Color("Neutral-300"))

                HStack {
                    TextField("Username", text: $username)
                        .frame(width: .infinity, height: 49)
                        .appFont(AppFont.body1)
                        .padding(.leading, 18)
                        .background(Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .inset(by: 0.35)
                            .stroke(Color("Neutral-600")))
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
                            .frame(width: .infinity, height: 50)
                            .foregroundColor(username.isEmpty ? .white : Color("Neutral-900"))
                            .padding(.horizontal, 29)
                            .background(username.isEmpty ? Color("Neutral-800") : Color("Green-300"))
                            .cornerRadius(8)
                    }
                    .disabled(username.isEmpty)
                }

                if let status = usernameStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(usernameStatusColor)
                        .padding(.leading, 11)
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
        .padding(.horizontal, 16)
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
