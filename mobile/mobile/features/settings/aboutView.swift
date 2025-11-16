import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    private let aboutText = loadAbout()
    
    
    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()
            
            VStack {
                ScrollView {
                    TopNavBar(title: "About") {
                        dismiss()
                    }
                    
                    Text(aboutText)
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

func loadAbout() -> String {
    guard let url = Bundle.main.url(forResource: "About", withExtension: "txt"),
          let text = try? String(contentsOf: url) else {
        return "Failed to load About."
    }
    return text
}


struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AboutView()
        }
    }
}
