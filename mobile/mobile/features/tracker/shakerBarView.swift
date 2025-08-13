import SwiftUI

struct ShakerBarView: View {
    let shakerRecord: ShakerRecord?
    
    var body: some View {
        // global varialbe for shaker size on tracker
        let shakerWidth = 36.0
        let lidHeight = 6.12
        let progressWidth = 33.07
        let progressHeight = 26.71
        let gap = shakerWidth - progressWidth
        
        let totalCount = shakerRecord?.totalCount ?? 0
        let progress = shakerRecord?.progress
        let lidColor = shakerRecord?.lidColor
        
        ZStack(alignment: .bottom) {
            if totalCount == 0 {
                Image("emptyShaker")
                    .resizable()
                    .scaledToFit()
                    .frame(width: shakerWidth, height: shakerWidth)
            } else {
                Image("trackerShaker")
                    .resizable()
                    .scaledToFit()
                    .frame(width: shakerWidth, height: shakerWidth)
                
                if let progress = progress {
                    let percentage = CGFloat(progress) / 100.0
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(
                            width: progressWidth,
                            height: (progressHeight * percentage)
                        )
                        .padding(gap / 2) // lift from bottom
                    
                    // shaker lid
                    if percentage == 1.0, let lidColor = lidColor {
                        VStack {
                            RoundedRectangle(cornerRadius: 1)
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
