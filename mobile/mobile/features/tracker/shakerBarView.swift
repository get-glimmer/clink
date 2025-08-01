import SwiftUI

// View that represents a shaker on a tracker
struct ShakerBarView: View {
    let progress: Int?   // nil if no record
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)

            if let progress = progress {
                let percentage = CGFloat(progress) / 100.0

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue)
                    .frame(width: size, height: size * percentage)
            }
        }
        .frame(height: size)
    }
}

