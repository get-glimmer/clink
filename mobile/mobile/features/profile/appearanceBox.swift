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
                Spacer()
                HStack {
                    Text(title)
                        .appFont(AppFont.captionM)
                        .foregroundColor(isSelected ? .white : Color("Neutral-600"))
                    Spacer()
                }
            }
            .padding(16)
            .frame(width: 110, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("Neutral-900"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? .white : Color("Neutral-600"), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
