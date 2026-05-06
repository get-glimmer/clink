import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    // Example notification toggles
    @State private var notif1 = false
    @State private var notif2 = true
    @State private var notif3 = true
    @AppStorage(ShakerScene.hapticsEnabledDefaultsKey) private var shakerHapticsEnabled = true
    
    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()
            
            
            
            ScrollView {
                TopNavBar(title: "Settings") {
                    dismiss()
                }
                .padding(.horizontal, 16)
                
                VStack {
                    // MARK: - My Account Block
                    VStack {
                        // Header
                        HStack {
                            Text("My Account")
                                .appFont(AppFont.labelL)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 6)
                        .padding(.leading, 10)
                        
                        Divider()
                        
                        // Username row
                        NavigationLink(destination: UsernameView()) {
                            HStack {
                                Text("Username")
                                    .padding(.top, 14)
                                    .padding(.bottom, 13)
                                    .appFont(AppFont.captionM)
                                    .foregroundStyle(Color(.white))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color("Neutral-400"))
                            }
                            .padding(.leading, 18)
                            .padding(.trailing, 16)
                        }
                        Divider()
                    }
                    
                    // MARK: - Notifications Block
                    VStack {
                        HStack {
                            Text("Notifications")
                                .appFont(AppFont.labelL)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 6)
                        .padding(.leading, 10)
                        
                        Divider()
                        
                        Toggle("Notification 01", isOn: $notif1)
                            .padding(.vertical, 5)
                            .padding(.leading, 18)
                            .padding(.trailing, 12)
                            .tint(Color("Green-300"))
                            .appFont(AppFont.captionM)
                            .foregroundStyle(Color(.white))
                        
                        Divider()
                        
                        Toggle("Notification 02", isOn: $notif2)
                            .padding(.vertical, 5)
                            .padding(.leading, 18)
                            .padding(.trailing, 12)
                            .tint(Color("Green-300"))
                            .appFont(AppFont.captionM)
                            .foregroundStyle(Color(.white))
                        
                        Divider()
                        
                        Toggle("Notification 03", isOn: $notif3)
                            .padding(.vertical, 5)
                            .padding(.leading, 18)
                            .padding(.trailing, 12)
                            .tint(Color("Green-300"))
                            .appFont(AppFont.captionM)
                            .foregroundStyle(Color(.white))


                        Divider()
                    }

                    // MARK: - Experience Block
                    VStack {
                        HStack {
                            Text("Experience")
                                .appFont(AppFont.labelL)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 6)
                        .padding(.leading, 10)

                        Divider()

                        Toggle("Shaker Haptics", isOn: $shakerHapticsEnabled)
                            .padding(.vertical, 5)
                            .padding(.leading, 18)
                            .padding(.trailing, 12)
                            .tint(Color("Green-300"))
                            .appFont(AppFont.captionM)
                            .foregroundStyle(Color(.white))

                        Divider()
                    }
                    
                    // MARK: - Privacy & Security Block
                    VStack {
                        HStack {
                            Text("Privacy & Security")
                                .padding(.top, 24)
                                .padding(.bottom, 6)
                                .padding(.leading, 10)
                                .appFont(AppFont.labelL)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        Divider()
                        
                        NavigationLink(destination: PrivacyPolicyView()) {
                            HStack {
                                Text("Privacy Policy")
                                    .padding(.top, 14)
                                    .padding(.bottom, 13)
                                    .appFont(AppFont.captionM)
                                    .foregroundStyle(Color(.white))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color("Neutral-400"))
                            }
                            .padding(.leading, 18)
                            .padding(.trailing, 16)
                        }
                        
                        Divider()
                    }
                    
                    // MARK: - Help & Support Block
                    VStack {
                        HStack {
                            Text("Help & Support")
                                .padding(.top, 24)
                                .padding(.bottom, 6)
                                .padding(.leading, 10)
                                .appFont(AppFont.labelL)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        Divider()
                        
                        NavigationLink(destination: TermsOfServiceView()) {
                            HStack {
                                Text("Terms of Service")
                                    .padding(.top, 14)
                                    .padding(.bottom, 13)
                                    .appFont(AppFont.captionM)
                                    .foregroundStyle(Color(.white))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color("Neutral-400"))
                            }
                            .padding(.leading, 18)
                            .padding(.trailing, 16)
                        }
                        
                        Divider()
                        
                        NavigationLink(destination: AboutView()) {
                            HStack {
                                Text("About")
                                    .padding(.top, 14)
                                    .padding(.bottom, 13)
                                    .appFont(AppFont.captionM)
                                    .foregroundStyle(Color(.white))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color("Neutral-400"))
                            }
                            .padding(.leading, 18)
                            .padding(.trailing, 16)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Version")
                                .padding(.top, 14)
                                .padding(.bottom, 13)
                                .appFont(AppFont.captionM)
                                .foregroundStyle(Color(.white))
                            Spacer()
                            Text("1.0")
                                .appFont(AppFont.labelS)
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 18)
                        .padding(.trailing, 16)
                        
                        Divider()
                    }
                    .padding(.bottom, 40)
                    
                    // MARK: - Logout / Delete Block
                    VStack (alignment: .leading,) {
                        Divider()
                            .background(Color("Neutral-600"))
                            .padding(.horizontal, -16)
                        
                        Button(role: .destructive) {
                            Task {
                                await authViewModel.logout()
                            }
                        } label: {
                            HStack {
                                Text("Logout")
                                    .foregroundColor(Color("Red-300"))
                                    .appFont(AppFont.captionM)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .padding(.leading, 18)
                            .contentShape(Rectangle()) // Make entire HStack tappable
                        }
                        
                        Divider()
                            .background(Color("Neutral-600"))
                            .padding(.horizontal, -16)
                        
                        NavigationLink(destination: DeleteAccountView()) {
                            HStack {
                                Text("Delete Account")
                                    .foregroundColor(Color("Red-300"))
                                    .appFont(AppFont.captionM)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .padding(.leading, 18)
                            .contentShape(Rectangle()) // Make entire HStack tappable
                        }
                        
                        Divider()
                            .background(Color("Neutral-600"))
                            .padding(.horizontal, -16)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
            }
            .navigationBarBackButtonHidden(true)
        }
        .navBarHidden(true)
    }

}

extension View {
    func subTextStyle() -> some View {
        self
//            .padding(.leading, 5)
//            .foregroundColor(.primary)
//            .font(.body)
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
