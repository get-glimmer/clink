import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    private let termsOfServiceText = loadTermsOfService()
    
    
    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()
            
            VStack {
                ScrollView {
                    TopNavBar(title: "Terms of Service") {
                        dismiss()
                    }
                    
                    Text(termsOfServiceText)
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

func loadTermsOfService() -> String {
    guard let url = Bundle.main.url(forResource: "TermsOfService", withExtension: "txt"),
          let text = try? String(contentsOf: url) else {
        return "Failed to load TermsOfService."
    }
    return text
}

struct TermsOfServiceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TermsOfServiceView()
        }
    }
}
