import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var text: String = ""

    var body: some View {
        ScrollView {
            TopNavBar(title: "Delete Account") {
                dismiss()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    (
                        Text("Are you sure you want to") +
                        Text(" delete ").foregroundColor(Color("Red-300")) +
                        Text("your account?")
                    )
                    .appFont(AppFont.title2)
                }
                .padding(.vertical)
                
                
                
                VStack (alignment: .leading, spacing: 5) {
                    Text("We're really sorry to see you go..")
                    Text("Once you confirm, your data will be gone.")
                }
                
                Spacer()
                Spacer()
                
                Text("Please let us know the reason for deleting your account.")
                TextField("Enter the reason for account deletion.", text: $text)
                    .foregroundStyle(Color("Neutral-600"))
                    .padding()
                    .frame(height: 100, alignment: .topLeading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("Neutral-600"), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading) // <--- important
            .padding()
        }
        Button(role: .destructive) {
            Task {
                await authViewModel.deleteAccount()
                dismiss()
            }
        } label: {
            Text("Delete Account")
                .foregroundColor(Color(.white))
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
        }
        .background(Color("Red-400"))
        .cornerRadius(10)
        .padding(.horizontal, 10)
        .padding(.bottom, 20)
        .navigationBarBackButtonHidden(true)
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
