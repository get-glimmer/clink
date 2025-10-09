import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    // Example notification toggles
    @State private var notif1 = false
    @State private var notif2 = true
    @State private var notif3 = true
    
    var body: some View {
        ScrollView {
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
                Text("Settings")
                    .appFont(AppFont.title2)
                    .foregroundColor(.white)
                Spacer()
                Circle()
                    .frame(width: 40, height: 40)
                    .opacity(0)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            VStack(spacing: 20) {
                
                // MARK: - My Account Block
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("My Account")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Username row
                    NavigationLink(destination: UsernameView()) {
                        HStack {
                            Text("Username")
                                .subTextStyle()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                }
                .padding(.horizontal)
                
                // MARK: - Notifications Block
                VStack(spacing: 0) {
                    HStack {
                        Text("Notifications")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    Toggle("Notification 01", isOn: $notif1)
                        .tint(Color("Green-300"))
                        .subTextStyle()
                        .padding(.vertical, 12)
                    
                    Divider()
                    
                    Toggle("Notification 02", isOn: $notif2)
                        .tint(Color("Green-300"))
                        .subTextStyle()
                        .padding(.vertical, 12)
                    
                    Divider()
                    
                    Toggle("Notification 03", isOn: $notif3)
                        .tint(Color("Green-300"))
                        .subTextStyle()
                        .padding(.vertical, 12)
                    
                    Divider()
                }
                .padding(.horizontal)
                
                // MARK: - Privacy & Security Block
                VStack(spacing: 0) {
                    HStack {
                        Text("Privacy & Security")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack {
                            Text("Privacy Policy")
                                .subTextStyle()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                }
                .padding(.horizontal)
                
                // MARK: - Help & Support Block
                VStack(spacing: 0) {
                    HStack {
                        Text("Help & Support")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    NavigationLink(destination: TermsOfServiceView()) {
                        HStack {
                            Text("Terms of Service")
                                .subTextStyle()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                    
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Text("About")
                                .subTextStyle()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Version")
                            .subTextStyle()
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    
                    Divider()
                }
                .padding(.horizontal)
                
                Spacer()
                
                // MARK: - Logout / Delete Block
                VStack(spacing: 0) {
                    Divider()
                        .background(Color("Neutral-600"))
                    
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.logout()
                        }
                    } label: {
                        Text("Logout")
                            .foregroundColor(Color("Red-300"))
                            .subTextStyle()
                            .padding(.vertical, 12)
                    }
                    
                    Divider()
                        .background(Color("Neutral-600"))
                    
                    NavigationLink(destination: DeleteAccountView()) {
                        Text("Delete Account")
                            .foregroundColor(Color("Red-300"))
                            .subTextStyle()
                            .padding(.vertical, 12)
                    }
                    
                    Divider()
                        .background(Color("Neutral-600"))
                    
                    Spacer()
                    
                    
                }
                .padding(.horizontal)
                
            }
            .padding(.vertical)
        }
        //.navBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

extension View {
    func subTextStyle() -> some View {
        self
            .padding(.leading, 5)
            .foregroundColor(.primary)
            .font(.body)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(AuthViewModel())
        }
    }
}
