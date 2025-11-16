import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var text: String = ""

    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()
            
            VStack {
                TopNavBar(title: "Delete Account") {
                    dismiss()
                }
                
                ScrollView {
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading) {
                            (
                                Text("Are you sure you want to") +
                                Text(" delete ").foregroundColor(Color("Red-300")) +
                                Text("your account?")
                            )
                            .appFont(AppFont.title2)
                        }
                        .padding(.horizontal, 11)
                        .padding(.top, 28)
                        
                        
                        
                        VStack (alignment: .leading) {
                            Text("We're really sorry to see you go..")
                            Text("Once you confirm, your data will be gone.")
                        }
                        .appFont(AppFont.body2)
                        .foregroundStyle(Color("Neutral-300"))
                        .padding(.horizontal, 11)
                        .padding(.top, 20)
                        
                        
                        Text("Please let us know the reason for deleting your account.")
                            .padding(.horizontal, 11)
                            .padding(.top, 67)
                            .padding(.bottom, 12)
                        
                        TextField("Enter the reason for account deletion.", text: $text)
                            .padding(.top, 12)
                            .padding(.leading, 19)
                            .foregroundColor(.white) // ✅ makes user input text white
                            .frame(height: 162, alignment: .topLeading)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color("Neutral-600"), lineWidth: 1)
                            )

                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // <--- important
                    .padding(.bottom, 205)
                    
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.deleteAccount()
                            dismiss()
                        }
                    } label: {
                        Text("Delete Account")
                            .appFont(AppFont.buttonL)
                            .foregroundColor(Color(.white))
                            .frame(maxWidth: .infinity)
                    }
                    .frame(width: 361, height: 50, alignment: .center)
                    
                    .background(Color("Red-400"))
                    .cornerRadius(8)
                    .navigationBarBackButtonHidden(true)
                }
                
            }
            .padding(.horizontal, 16)
        }
        .navBarHidden(true)
        .dismissKeyboardOnTap()
    }
}

struct DeleteAccountView_Previews: PreviewProvider {
    @State static var text = "" // For binding in the TextField

    static var previews: some View {
        NavigationStack {
            DeleteAccountView()
                .environmentObject(AuthViewModel()) // Provide sample AuthViewModel
                .preferredColorScheme(.dark)        // Optional, matches your black background
        }
    }
}
