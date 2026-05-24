import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var notifChallenge: Bool = true
    @State private var notifTasks: Bool = true
    @State private var notifCommunity: Bool = true
    @State private var notifGeneral: Bool = true
    @State private var prefsLoaded: Bool = false


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
                    
                    // MARK: - Notification Types Block
                    VStack {
                        HStack {
                            Text("Notification Types")
                                .appFont(AppFont.labelL)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 6)
                        .padding(.leading, 10)

                        Divider()

                        notifToggleRow("Challenge", isOn: $notifChallenge)

                        Divider()

                        notifToggleRow("Tasks", isOn: $notifTasks)

                        Divider()

                        notifToggleRow("Community", isOn: $notifCommunity)

                        Divider()

                        notifToggleRow("General", isOn: $notifGeneral)

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
                        
                        Button {
                            if let url = URL(string: "https://drive.google.com/file/d/1XnvkL7RAV3MCYENBbi_zybKy-hW8VHio/view") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
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
                        
                        Button {
                            if let url = URL(string: "https://drive.google.com/file/d/1_uQArj0EZwjtRdZWeu2Nk8c2ChsZnPXT/view") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
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
                        
                        Button {
                            if let url = URL(string: "https://www.notion.so/Clink-Support-3574cf9788df801d9d40f900b123a230") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Text("Support")
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
        .task { await loadPrefs() }
        .onChange(of: notifChallenge) { _, _ in saveIfLoaded() }
        .onChange(of: notifTasks)     { _, _ in saveIfLoaded() }
        .onChange(of: notifCommunity) { _, _ in saveIfLoaded() }
        .onChange(of: notifGeneral)   { _, _ in saveIfLoaded() }
    }

    private struct NotifPrefsRow: Codable {
        let user_id: String
        let challenge: Bool
        let tasks: Bool
        let community: Bool
        let general: Bool
    }

    private func loadPrefs() async {
        guard let supabase = SupabaseClientManager.shared.client else { return }
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString.lowercased()
            let row: NotifPrefsRow? = try? await supabase
                .from("notification_preferences")
                .select("user_id, challenge, tasks, community, general")
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            if let row {
                notifChallenge = row.challenge
                notifTasks = row.tasks
                notifCommunity = row.community
                notifGeneral = row.general
            }
        } catch {
            print("notif prefs load error:", error.localizedDescription)
        }
        prefsLoaded = true
    }

    private func saveIfLoaded() {
        guard prefsLoaded else { return }
        Task { await savePrefs() }
    }

    private func savePrefs() async {
        guard let supabase = SupabaseClientManager.shared.client else { return }
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString.lowercased()
            let row = NotifPrefsRow(
                user_id: userId,
                challenge: notifChallenge,
                tasks: notifTasks,
                community: notifCommunity,
                general: notifGeneral
            )
            try await supabase
                .from("notification_preferences")
                .upsert(row, onConflict: "user_id")
                .execute()
        } catch {
            print("notif prefs save error:", error.localizedDescription)
        }
    }

    private func notifToggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .appFont(AppFont.captionM)
                .foregroundStyle(.white)
        }
        .tint(Color("Green-300"))
        .padding(.vertical, 6)
        .padding(.leading, 18)
        .padding(.trailing, 16)
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
