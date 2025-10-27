import SwiftUI

struct BottomRoundedRectangle: Shape {
    var cornerRadius: CGFloat = 2

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)

        // Start at top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Top edge to top-right (square corners on top)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Right edge down to just above bottom-right corner arc
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        // Bottom-right corner arc
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        // Bottom edge to just before bottom-left corner arc
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        // Bottom-left corner arc
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        // Left edge back to start
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }
}

struct ShakerBarView: View {
    let shakerRecord: ShakerRecord?
    
    var body: some View {
        // global varialbe for shaker size on tracker
        let shakerWidth = 28.30084
        let shakerHeight = 23.32577
        let lidHeight = 4.81196
        let progressWidth = 26.0
        let progressHeight = 21.0
        
        let totalCount = shakerRecord?.totalCount ?? 0
        let progress = shakerRecord?.progress
        let lidColor = shakerRecord?.lidColor
        
        ZStack(alignment: .bottom) {
            if totalCount == 0 {
                VStack(spacing: 0) {
                    Image("noTaskShaker")
                        .resizable()
                        .scaledToFit()
                        .frame(width: shakerWidth, height: shakerHeight+lidHeight)
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
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("Neutral-800"))
                        .frame(
                            width: shakerWidth,
                            height: shakerHeight
                        )
                }
                
                if let progress = progress {
                    let percentage = CGFloat(progress) / 100.0
                    
                    Group {
                        if percentage < 1.0 {
                            BottomRoundedRectangle(cornerRadius: 3)
                                .fill(Color("Neutral-50"))
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color("Neutral-50"))
                        }
                    }
                    .frame(
                        width: progressWidth,
                        height: (progressHeight * percentage)
                    )
                    .padding(.bottom, 1.14)
                    
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


import SwiftUI

#Preview {
    VStack(spacing: 20) {
        // Empty shaker (no progress)
        ShakerBarView(
            shakerRecord: ShakerRecord(
                progress: 0,
                completedCount: 0,
                totalCount: 0,
                lidColor: LinearGradient(
                    colors: [.gray, .gray],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
        
        // Half-filled shaker
        ShakerBarView(
            shakerRecord: ShakerRecord(
                progress: 90,
                completedCount: 4,
                totalCount: 10,
                lidColor: LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
        
        // Full shaker (lid visible)
        ShakerBarView(
            shakerRecord: ShakerRecord(
                progress: 100,
                completedCount: 10,
                totalCount: 10,
                lidColor: LinearGradient(
                    colors: [.green, .mint],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
    }
    .padding()
    .background(Color("Neutral-1000"))
}
