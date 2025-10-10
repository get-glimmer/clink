import SwiftUI

struct TopNavBar: View {
    var title: String
    var onBack: (() -> Void)?

    var body: some View {
        HStack() {
            // Back button
            if let onBack {
                Button(action: onBack) {
                    Image("back_button")
                }
            } else {
                // If no back button needed, keep space
                Color.clear.frame(width: 40, height: 40)
            }

            Spacer()
            // Title
            Text(title)
                .appFont(AppFont.title2)
                .foregroundColor(.white)
            
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .background(.neutral1000)
//        .padding(.horizontal, 16)
        .padding(.top, 15)
    }
}

struct TopNavBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With back button
            TopNavBar(title: "Finish Signing Up") {
                print("Back tapped")
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("With Back Button")
            
            // Without back button
            TopNavBar(title: "Profile")
                .preferredColorScheme(.dark)
                .previewDisplayName("Without Back Button")
        }
    }
}
