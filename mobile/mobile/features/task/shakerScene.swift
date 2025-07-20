//
//  shakerScene.swift
//  mobile
//

import SpriteKit
import CoreMotion
import Vision
import VisionKit

final class ShakerScene: SKScene {

    // MARK: - Motion
    private let motion = CMMotionManager()
    private var isMotionOn = false

    // filter
    private var filteredGravity = CGVector.zero
    private let gAlpha:  CGFloat = 0.2   // gravity LPF
    private let accScale: CGFloat = 600  // shaking force scale

    // MARK: - Gravity presets
    private let airGravity = CGVector(dx: 0, dy: -10)    // (OFF mode) gravity
    private let oilGravityScale:  CGFloat = 10          // (ON mode) gravity

    // MARK: - Edge-loop inset
    private let inset: CGFloat = 12
    private let lidHeight: CGFloat = 30

    // MARK: - Life-cycle
    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = .init(x: 0.5, y: 0.5)
    }
    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = .clear

        /* ----- edge-loop smaller than PNG ----- */
        let rect = CGRect(x: -size.width/2  + inset,
                          y: -size.height/2 + inset,
                          width:  size.width  - inset*2,
                          height: size.height - inset*2 - lidHeight)
        let wall = SKPhysicsBody(edgeLoopFrom: rect)
        wall.friction = 0
        physicsBody   = wall
        physicsBody?.isDynamic = false

        physicsWorld.gravity = airGravity
    }
    

    // MARK: - Public toggles
    func toggleShaker() {
        isMotionOn.toggle()
        isMotionOn ? startMotion() : stopMotion()
        updateMarbleParameters()        // 각 구슬 damping 등 전환
    }

    // MARK: - Motion handlers
    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0   // 60 Hz
        
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let dm = data else { return }
            
            /* 1. tilting → apply gravity */
            let gx = dm.gravity.x
            let gy = dm.gravity.y
            filteredGravity.dx = gAlpha * filteredGravity.dx + (1-gAlpha) * gx
            filteredGravity.dy = gAlpha * filteredGravity.dy + (1-gAlpha) * gy
            physicsWorld.gravity = CGVector(dx: filteredGravity.dx * self.oilGravityScale,
                                            dy: filteredGravity.dy * self.oilGravityScale)
            
            /* 2. shaking → apply force to each marble */
            let ua = dm.userAcceleration
            //let ax = abs(ua.x) > 0.02 ? ua.x : 0
            //let ay = abs(ua.y) > 0.02 ? ua.y : 0
            let ax = ua.x
            let ay = ua.y
            let mag = hypot(ax, ay)

            // 임계값 이상일 때만 힘 주입
            if mag > 0.02 {
                let baseForce = CGVector(dx: ax * accScale,
                                         dy: ay * accScale)
                
                for case let label as SKLabelNode in self.children {
                    guard let body = label.physicsBody else { continue }
                    
                    // ➜ 무작위 각도 ±15° 회전, 길이는 80~120 % 랜덤
                    let angleJitter = CGFloat.random(in: -(.pi/12)...(.pi/12))
                    let lenFactor   = CGFloat.random(in: 0.7...1.3)
                    
                    let rotated = CGVector(dx:  baseForce.dx * cos(angleJitter)
                                                  - baseForce.dy * sin(angleJitter),
                                           dy:  baseForce.dx * sin(angleJitter)
                                                  + baseForce.dy * cos(angleJitter))
                    
                    let final = CGVector(dx: rotated.dx * lenFactor,
                                         dy: rotated.dy * lenFactor)
                    
                    body.applyForce(final)
                }
            }
        }
    }
    private func stopMotion() {
        motion.stopDeviceMotionUpdates()
        physicsWorld.gravity = airGravity
        //filteredAccel = .zero
    }

    // MARK: - Drop new marble
    func dropEmoji(_ symbol: String) {
        let margin: CGFloat = 14
        let minX = -size.width/2 + margin
        let maxX =  size.width/2 - margin
        let spawnX = CGFloat.random(in: minX...maxX)
        let spawnY =  size.height/2 - margin*2 - lidHeight - margin

        let node = SKLabelNode(fontNamed: "AppleColorEmoji")
        node.text = symbol
        node.fontSize = 54
        node.verticalAlignmentMode = .center
        node.position = CGPoint(x: spawnX, y: spawnY)
        node.zPosition = 50

        node.physicsBody = makeBody()
        addChild(node)
        

    }

    // MARK: - Helpers
    /// Returns a circular physics body with parameters depending on current mode.
    private func makeBody() -> SKPhysicsBody {
        let body = SKPhysicsBody(circleOfRadius: 25.6) // fontsize / 2.111..
        body.usesPreciseCollisionDetection = true
        if isMotionOn {
            body.restitution = 0.1
            body.friction = 0.9
            body.linearDamping = 0.8
            body.angularDamping = 0.9
        } else {
            body.restitution = 0.05
            body.friction = 0.9
            body.linearDamping = 0.4
            body.angularDamping = 0.8
        }
        return body
    }

    /// Update existing marbles to match current mode.
    private func updateMarbleParameters() {
        for case let label as SKLabelNode in children {
            label.physicsBody = makeBody()
        }
    }

    /// Remove all marbles, keep walls.
    func resetScene() {
        for child in children where child is SKLabelNode {
            child.removeFromParent()
        }
    }
}

// MARK: - Color Extraction
extension ShakerScene {

    /// Returns up to `maxCount` dominant UIColors in the current scene snapshot.
    ///   1) SpriteKit → CGImage 로 스냅샷
    ///   2) 64×64 로 다운스케일하여 픽셀 색상 수집
    ///   3) RGB 5-bit(15-bit) 로 양자화 후 히스토그램 집계
    ///   4) 상위 N개 버킷을 UIColor 로 변환
    func dominantColors(maxCount: Int = 3) -> [UIColor] {

        // ── 1. SKScene snapshot → CGImage ──
        guard let view,
              let texture = view.texture(from: self) else { return [] }

        // iOS 17 이상은 cgImage() 지원, 그 이하 버전은 UIImage로 우회
        let cgImage: CGImage
        if #available(iOS 17.0, *) {
            cgImage = texture.cgImage()
        } else {
            guard let ui = texture.uiImage(),
                  let cg = ui.cgImage else { return [] }
            cgImage = cg
        }

        // ── 2. Crop & Downscale snapshot ──
        let halfH   = cgImage.height / 2
        let cropRect = CGRect(x: 0,
                              y: halfH,  
                              width: cgImage.width,
                              height: halfH)      // keep bottom half
        guard let cgImage = cgImage.cropping(to: cropRect) else { return [] }

        let w = 64, h = 64         // small for performance
        guard let ctx = CGContext(data: nil,
                                  width: w, height: h,
                                  bitsPerComponent: 8,
                                  bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return [] }

        ctx.interpolationQuality = .low
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return [] }
        let pixels = data.bindMemory(to: UInt8.self, capacity: w * h * 4)

        // ── 3. 양자화 히스토그램 (R5-G5-B5) ──
        var hist: [UInt32: Int] = [:]
        for y in stride(from: 0, to: h, by: 2) {        // 1/4 샘플
            for x in stride(from: 0, to: w, by: 2) {
                let off = 4 * (y * w + x)
                let r = pixels[off]     >> 3            // 0‥31
                let g = pixels[off + 1] >> 3
                let b = pixels[off + 2] >> 3
                let key = UInt32(r) << 10 | UInt32(g) << 5 | UInt32(b)
                hist[key, default: 0] += 1
            }
        }

        // ── 4. 상위 maxCount 색 찾기 ──
        let sorted = hist.sorted { $0.value > $1.value }
        return sorted.prefix(maxCount).map { entry in
            let key = entry.key
            let r = CGFloat(((key >> 10) & 0x1F) << 3) / 255.0
            let g = CGFloat(((key >>  5) & 0x1F) << 3) / 255.0
            let b = CGFloat(( key        & 0x1F) << 3) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: 1.0)
        }
    }
}

// MARK: - SKTexture → UIImage helper (iOS16- fallback)
private extension SKTexture {
    func uiImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size().width,
                                                            height: size().height))
        return renderer.image { _ in
            UIImage(cgImage: cgImage())        
                .draw(in: CGRect(origin: .zero,
                                 size: CGSize(width: size().width,
                                              height: size().height)))
        }
    }
}
