import UIKit
import SwiftUI

struct CircleCropView: View {
    @Binding var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image = image {
                GeometryReader { geo in
                    let size = geo.size
                    
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: size.width, height: size.width)
                        .clipped()
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = value.translation
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, value)
                                }
                        )
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .overlay(
            VStack {
                Spacer()
                Button("Use Photo") {
                    if let image = image {
                        let cropped = cropToCircle(image: image, scale: scale, offset: offset)
                        self.image = cropped
                    }
                    dismiss()
                }
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .clipShape(Capsule())
            }
            .padding(),
            alignment: .bottom
        )
    }
    
    func cropToCircle(image: UIImage, scale: CGFloat, offset: CGSize) -> UIImage? {
        let minEdge = min(image.size.width, image.size.height)
        let size = CGSize(width: minEdge, height: minEdge)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(ovalIn: rect).addClip()
            
            let transform = CGAffineTransform.identity
                .translatedBy(x: offset.width, y: offset.height)
                .scaledBy(x: scale, y: scale)
            context.cgContext.concatenate(transform)
            
            image.draw(in: rect)
        }
    }
}
