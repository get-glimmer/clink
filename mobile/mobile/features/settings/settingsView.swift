import SwiftUI
import Supabase

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authViewModel = AuthViewModel()
    
    // Example notification toggles
    @State private var notif1 = false
    @State private var notif2 = true
    @State private var notif3 = true
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - My Account
                Section(header: sectionHeader("My Account")) {
                    NavigationLink(destination: UsernameView()) {
                        HStack {
                            Text("Username")
                                .subTextStyle()
                            Spacer()
                        }
                    }
                    
                }
                
                // MARK: - Notifications
                Section(header: sectionHeader("Notifications")) {
                    Toggle("Notification 01", isOn: $notif1)
                        .subTextStyle()
                    Toggle("Notification 02", isOn: $notif2)
                        .subTextStyle()
                    Toggle("Notification 03", isOn: $notif3)
                        .subTextStyle()
                }
                
                // MARK: - Privacy & Security
                Section(header: sectionHeader("Privacy & Security")) {
                    NavigationLink("Privacy Policy", destination: PrivacyPolicyView())
                        .subTextStyle()
                }
                
                // MARK: - Help & Support
                Section(header: sectionHeader("Help & Support")) {
                    NavigationLink("Terms of Service", destination: TermsOfServiceView())
                        .subTextStyle()
                    NavigationLink("About", destination: AboutView())
                        .subTextStyle()
                    
                    HStack {
                        Text("Version")
                            .subTextStyle()
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.gray)
                    }
                }
                
                // MARK: - Logout / Delete
                Spacer()
                Button(role: .destructive) {
                    Task {
                        await authViewModel.logout()
                        dismiss()
                    }
                } label: {
                    Text("Logout")
                        .foregroundColor(.red)
                        .subTextStyle()
                }
                
                Button(role: .destructive) {
                    Task {
                        await authViewModel.deleteAccount()
                        dismiss()
                    }
                } label: {
                    Text("Delete Account")
                        .foregroundColor(.red)
                        .subTextStyle()
                }
                
            }
            .navigationTitle("Settings")
            .listStyle(.plain)
        }
        .navigationBarBackButtonHidden(true) // hide default "Back" text

        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color("Neutral-900"))
                            .frame(width: 40, height: 40)
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color("Neutral-400"))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .environmentObject(authViewModel)
    }
}

extension View {
    func subTextStyle() -> some View {
        self
            .padding(.leading, 5)  // adjust indent
            .foregroundColor(.primary)
            .font(.body)
    }
}

func sectionHeader(_ text: String) -> some View {
    Text(text)
        .font(.headline)
        .fontWeight(.bold)
        .foregroundColor(.white)
}


#Preview {
    SettingsView()
}
