import SwiftUI

struct ShakerBarView: View {
    let shakerRecord: ShakerRecord?
    
    var body: some View {
        // global varialbe for shaker size on tracker
        let shakerWidth = 32.0
        let shakerHeight = 23.33 * (shakerWidth / 28.14)
        let lidHeight = 4.81 * (shakerWidth / 28.14)
        let progressWidth = 26.0 * (shakerWidth / 28.14)
        let progressHeight = 21.0 * (shakerWidth / 28.14)
        let gap = shakerWidth - progressWidth
        
        let totalCount = shakerRecord?.totalCount ?? 0
        let progress = shakerRecord?.progress
        let lidColor = shakerRecord?.lidColor
        
        ZStack(alignment: .bottom) {
            if totalCount == 0 {
                    VStack(spacing: 0) {
                        // lid
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color("Neutral-800"))
                            .frame(
                                width: shakerWidth,
                                height: lidHeight
                            )
                        ZStack {
                            // shaker
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color("Neutral-800"))
                                .frame(
                                    width: shakerWidth,
                                    height: shakerHeight
                                )
                            Image("emptyShaker")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 13, height: 13)
                        }
                    }
                
            } else {
                VStack(spacing: 0) {
                    // lid
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color("Neutral-800"))
                        .frame(
                            width: shakerWidth,
                            height: lidHeight
                        )
                    // shaker
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color("Neutral-800"))
                        .frame(
                            width: shakerWidth,
                            height: shakerHeight
                        )
                }
                
                if let progress = progress {
                    let percentage = CGFloat(progress) / 100.0
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(
                            width: progressWidth,
                            height: (progressHeight * percentage)
                        )
                        .padding(gap / 2) // lift from bottom
                    
                    // shaker lid
                    if percentage == 1.0, let lidColor = lidColor {
                        VStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(lidColor)
                                .frame(
                                    width: shakerWidth,
                                    height: lidHeight
                                )
                            Spacer()
                        }
                    }
                    
                    
                }
            }
        }
        .frame(width: shakerWidth, height: shakerWidth)
    }
}
