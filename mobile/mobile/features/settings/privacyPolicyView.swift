import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    private let policyText = loadPrivacyPolicy()
    
    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()
            
            VStack {
                ScrollView {
                    TopNavBar(title: "Privacy Policy View") {
                        dismiss()
                    }
                    
                    Text(policyText)
                        .foregroundColor(Color("Neutral-200"))
                        .font(.system(size: 14))
                        .padding()
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .padding(.horizontal, 16)
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
        }
    }
}

func loadPrivacyPolicy() -> String {
    guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "txt"),
          let text = try? String(contentsOf: url) else {
        return "Failed to load Privacy Policy."
    }
    return text
}



struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PrivacyPolicyView()
        }
    }
}
