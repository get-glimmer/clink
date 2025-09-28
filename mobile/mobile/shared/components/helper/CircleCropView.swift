import SwiftUI
import UIKit

struct CircleCropView: View {
    @Binding var image: UIImage?
    var onCrop: ((UIImage) -> Void)? = nil  // optional closure
    
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
                            DragGesture().onChanged { value in offset = value.translation }
                        )
                        .gesture(
                            MagnificationGesture().onChanged { value in scale = max(1.0, value) }
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
                    guard let currentImage = image else { return }
                    let cropped = cropToCircle(image: currentImage)
                    image = cropped
                    onCrop?(cropped)  // call the closure if provided
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
    
    func cropToCircle(image: UIImage) -> UIImage {
        let minEdge = min(image.size.width, image.size.height)
        let size = CGSize(width: minEdge, height: minEdge)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(ovalIn: rect).addClip()
            image.draw(in: rect)
        }
    }
}
