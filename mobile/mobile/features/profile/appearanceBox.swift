import SwiftUI

// MARK: - Appearance Box Component
struct AppearanceBox: View {
    let iconName: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack {
                HStack {
                    Image(systemName: iconName)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(isSelected ? .white : Color("Neutral-600"))
                    Spacer()
                }
                .padding(.leading, 12)
                .padding(.top, 13)
                
                Spacer()
                
                HStack {
                    Text(title)
                        .appFont(AppFont.captionM)
                        .foregroundColor(isSelected ? .white : Color("Neutral-600"))
                    Spacer()
                }
                .padding(.leading, 15)
                .padding(.bottom, 14)
            }
            .frame(width: 110, height: 96)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("Neutral-900"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .inset(by: 0.5)
                            .stroke(isSelected ? .white : .clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct AppearanceBox_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            HStack(spacing: 16) {
                AppearanceBox(iconName: "circle.righthalf.filled", title: "System", isSelected: false) {}
                AppearanceBox(iconName: "sun.max", title: "Light", isSelected: false) {}
                AppearanceBox(iconName: "moon.fill", title: "Dark", isSelected: true) {}
            }
        }
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
