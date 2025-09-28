import SwiftUI

struct TopNavBar: View {
    var title: String
    var onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Back button
            if let onBack {
                Button(action: onBack) {
                    ZStack {
                        Circle()
                            .fill(Color("Neutral-900"))
                            .frame(width: 40, height: 40)
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color("Neutral-400"))
                            .frame(width: 14, height: 14)
                    }
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

            // Balance space on right side
            Color.clear.frame(width: 40, height: 40)
        }
        .frame(height: 50)
        .padding(.horizontal)
        .padding(.top, 10)
        .background(Color.black.ignoresSafeArea(edges: .top))
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
