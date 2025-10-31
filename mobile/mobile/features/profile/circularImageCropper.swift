import SwiftUI

struct CircularImageCropper: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    let minScale: CGFloat = 1.0
    let maxScale: CGFloat = 4.0

    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()

            GeometryReader { geo in
                VStack {
                    TopNavBar(title: "") {
                        dismiss()
                    }

                    ZStack {
                        if let uiImage = image {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    SimultaneousGesture(
                                        // MARK: - Drag
                                        DragGesture()
                                            .onChanged { value in
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                                clampOffset(in: geo.size, image: uiImage)
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                            },

                                        // MARK: - Zoom
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let newScale = lastScale * value
                                                scale = min(max(newScale, minScale), maxScale)
                                                clampOffset(in: geo.size, image: uiImage)
                                            }
                                            .onEnded { _ in
                                                lastScale = scale
                                            }
                                    )
                                )
                                .animation(.easeOut(duration: 0.25), value: offset)
                                .animation(.easeOut(duration: 0.25), value: scale)
                                .frame(width: geo.size.width, height: geo.size.width)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                                )
                                .contentShape(Circle())
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(.top, 120)

                    Spacer()

                    // MARK: - Continue Button
                    HStack {
                        Button {
                            if let baseImage = image {
                                if let result = renderCroppedImage(
                                    image: baseImage,
                                    size: geo.size.width,
                                    scale: scale,
                                    offset: offset
                                ) {
                                    self.image = result
                                }
                            }
                            dismiss()
                        } label: {
                            Text("Continue")
                                .appFont(AppFont.buttonL)
                                .frame(width: 361)
                                .frame(height: 50)
                                .background(Color("Green-300"))
                                .foregroundColor(Color("Neutral-900"))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 36)
                }
            }
            .padding(.horizontal, 16)
        }
        .navBarHidden(true)
    }

    // MARK: - Limit panning to image edges
    private func clampOffset(in size: CGSize, image: UIImage) {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = size.width / size.height

        var imageWidth = size.width
        var imageHeight = size.height

        if imageAspect > containerAspect {
            // Image is wider
            imageHeight = size.width / imageAspect
        } else {
            // Image is taller
            imageWidth = size.height * imageAspect
        }

        imageWidth *= scale
        imageHeight *= scale

        let maxX = max(0, (imageWidth - size.width) / 2)
        let maxY = max(0, (imageHeight - size.height) / 2)

        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
    }

    // MARK: - Render Cropped Circle
    func renderCroppedImage(image: UIImage, size: CGFloat, scale: CGFloat, offset: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()

            // Aspect fit logic
            let imgAspect = image.size.width / image.size.height
            var drawWidth = size
            var drawHeight = size

            if imgAspect > 1 {
                // Landscape
                drawHeight = size / imgAspect
            } else {
                // Portrait
                drawWidth = size * imgAspect
            }

            drawWidth *= scale
            drawHeight *= scale

            let drawX = (size - drawWidth) / 2 + offset.width
            let drawY = (size - drawHeight) / 2 + offset.height

            image.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }
    }
}

struct CircularImageCropper_Previews: PreviewProvider {
    static var previews: some View {
        let sampleImage = UIImage(systemName: "person.crop.circle.fill")!
        CircularImageCropper(image: .constant(sampleImage))
            .preferredColorScheme(.dark)
    }
}
