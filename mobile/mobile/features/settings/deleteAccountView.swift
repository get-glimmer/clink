import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var text: String = ""

    var body: some View {
        TopNavBar(title: "Delete Account") {
            dismiss()
        }
        
        VStack {
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
                    .padding(.top, 33)
                    
                    
                    
                    VStack (alignment: .leading) {
                        Text("We're really sorry to see you go..")
                        Text("Once you confirm, your data will be gone.")
                    }
                    .padding(.horizontal, 11)
                    .padding(.top, 24)
                
                    
                    Text("Please let us know the reason for deleting your account.")
                        .padding(.horizontal, 11)
                        .padding(.top, 68)
                    
                    TextField("Enter the reason for account deletion.", text: $text)
                        .padding(.top, 12)
                        .padding(.leading, 19)
                        .foregroundStyle(Color("Neutral-600"))
                        .frame(height: 100, alignment: .topLeading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color("Neutral-600"), lineWidth: 1)
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading) // <--- important
            }
            Button(role: .destructive) {
                Task {
                    await authViewModel.deleteAccount()
                    dismiss()
                }
            } label: {
                Text("Delete Account")
                    .foregroundColor(Color(.white))
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 361, height: 50, alignment: .center)
            .background(Color("Red-400"))
            .cornerRadius(8)
            .navigationBarBackButtonHidden(true)
        }
        .padding(.horizontal, 16)
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
