//
//  shakerScene.swift
//  mobile
//
//  Created by 이채린 on 7/21/25.
//


import SpriteKit
import CoreMotion
import Vision
import VisionKit
import UIKit

final class ShakerScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Motion & Storage
    private let motion = CMMotionManager()
    private var filteredGravity = CGVector.zero
    private let gAlpha:  CGFloat = 0.2   // gravity LPF
    private let accScale: CGFloat = 600  // shaking force scale
    private let gravityScale:  CGFloat = 12 // gravity applied to charms
    private var motionEnabled = false
    
    // Storage for marbles keyed by Task UUID
    private var marbles: [UUID: SKLabelNode] = [:]
    
    // MARK: - Edge-loop inset
    private let inset: CGFloat = 12
    private let lidHeight: CGFloat = 40
    
    // MARK: - Haptic settings
    var isHapticsEnabled: Bool = true
    private var lastHapticTime: TimeInterval = 0
    private let hapticCooldown: TimeInterval = 0.25
    
    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = .init(x: 0.5, y: 0.5)
        physicsWorld.contactDelegate = self
        //startMotion()         // commented out-> control from each view
    }
    required init?(coder: NSCoder) { fatalError("not implemented") }
    
    deinit { stopMotion() }
    
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        
        /* ----- edge-loop smaller than PNG ----- */
        let rect = CGRect(x: -size.width/2  + inset,
                          y: -size.height/2 + inset,
                          width:  size.width  - inset*2,
                          height: size.height - inset*2 - lidHeight)
        let wall = SKPhysicsBody(edgeLoopFrom: rect)
        wall.friction = 0
        wall.isDynamic = false
        wall.categoryBitMask = 0x1 << 1       // jar wall
        wall.contactTestBitMask = 0x1 << 0    // detect marble-wall contact
        physicsBody   = wall
    }
    
    // MARK: - Motion handlers
    func setMotionEnabled(_ enabled: Bool) {
        guard enabled != motionEnabled else { return }
        motionEnabled = enabled
        if enabled { startMotion() } else { stopMotion() }
    }
    
    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0   // 60 Hz
        
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let dm = data else { return }
            /* 1. tilting → apply gravity */
            let gx = dm.gravity.x
            let gy = dm.gravity.y
            self.filteredGravity.dx = self.gAlpha * self.filteredGravity.dx + (1-self.gAlpha) * gx
            self.filteredGravity.dy = self.gAlpha * self.filteredGravity.dy + (1-self.gAlpha) * gy
            self.physicsWorld.gravity = CGVector(dx: self.filteredGravity.dx * self.gravityScale,
                                                 dy: self.filteredGravity.dy * self.gravityScale)
            /* 2. shaking → apply force */
            let ua = dm.userAcceleration
            let ax = ua.x
            let ay = ua.y
            let mag = hypot(ax, ay)
            if mag > 0.02 {
                let baseForce = CGVector(dx: ax * self.accScale, dy: ay * self.accScale)
                for (_, label) in self.marbles {
                    if let body = label.physicsBody {
                        let angleJitter = CGFloat.random(in: -(.pi/12)...(.pi/12))
                        let lenFactor   = CGFloat.random(in: 0.7...1.3)
                        let rotated = CGVector(dx:  baseForce.dx * cos(angleJitter) - baseForce.dy * sin(angleJitter),
                                               dy:  baseForce.dx * sin(angleJitter) + baseForce.dy * cos(angleJitter))
                        let final = CGVector(dx: rotated.dx * lenFactor, dy: rotated.dy * lenFactor)
                        body.applyForce(final)
                    }
                }
            }
        }
    }
    
    private func stopMotion() {
        motion.stopDeviceMotionUpdates()
    }
    
    // MARK: - Marble handlers
    // Drops an emoji into the scene identified by taskId. If already exists it will be ignored.
    func addEmoji(_ symbol: String, for taskId: UUID) {
        guard marbles[taskId] == nil else { return }
        let margin: CGFloat = 14
        let minX = -size.width/2 + margin*2
        let maxX =  size.width/2 - margin*2
        let spawnX = CGFloat.random(in: minX...maxX)
        let spawnY =  size.height/2 - margin*2 - lidHeight - margin*(CGFloat.random(in: 2...3))
        
        let node = SKLabelNode(fontNamed: "AppleColorEmoji")
        node.text = symbol
        node.fontSize = 54
        node.verticalAlignmentMode = .center
        node.position = CGPoint(x: spawnX, y: spawnY)
        node.zPosition = 50
        node.physicsBody = makeBody()
        addChild(node)
        marbles[taskId] = node
    }
    
    // Removes the emoji associated with taskId if present.
    // Removes the emoji associated with taskId if present.
    func removeEmoji(for taskId: UUID) {
        guard let node = marbles[taskId] else { return }
        node.removeFromParent()
        marbles.removeValue(forKey: taskId)
    }
    
    // Clears all emojis (used when the entire task list resets)
    func resetScene() {
        for (_, node) in marbles { node.removeFromParent() }
        marbles.removeAll()
    }
    
    // MARK: - Helpers
    private func makeBody() -> SKPhysicsBody {
        let body = SKPhysicsBody(circleOfRadius: 25.6)
        body.usesPreciseCollisionDetection = true
        body.restitution = 0.1
        body.friction = 0.9
        body.linearDamping = 0.8
        body.angularDamping = 0.9
        
        // contact haptic
        body.categoryBitMask = 0x1 << 0      // marble
        body.contactTestBitMask = 0x1 << 0   // 다른 marble과 충돌
        body.collisionBitMask = 0xFFFFFFFF   // 기본 충돌
        return body
    }
    
    // MARK: - Contact delegate
    func didBegin(_ contact: SKPhysicsContact) {
        guard isHapticsEnabled else { return }
        let now = CACurrentMediaTime()
        if now - lastHapticTime > hapticCooldown {
            triggerHaptic()
            lastHapticTime = now
        }
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    
    // MARK: - Color Extraction (for gradient lid)
    // -- ver1. jar image, background color included --
    func dominantColors(maxCount: Int = 2) -> [UIColor] {
        
        // 1) Scene → CGImage
        guard let view,
              let texture = view.texture(from: self) else { return [] }
        
        let cg: CGImage
        if #available(iOS 17.0, *) {
            cg = texture.cgImage()
        } else {
            guard let ui = texture.uiImage(),
                  let cgImg = ui.cgImage else { return [] }
            cg = cgImg
        }
        
        // 2) Crop bottom half & down-scale
        let halfH   = cg.height / 2
        let crop    = CGRect(x: 0, y: halfH,
                             width: cg.width,
                             height: halfH)
        guard let bottom = cg.cropping(to: crop) else { return [] }
        
        let w = 64, h = 64
        guard let ctx = CGContext(data: nil,
                                  width: w, height: h,
                                  bitsPerComponent: 8,
                                  bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return [] }
        
        ctx.interpolationQuality = .low
        ctx.draw(bottom, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return [] }
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        
        // 3) 5-bit RGB quantisation histogram
        var hist: [UInt32: Int] = [:]
        for y in stride(from: 0, to: h, by: 2) {
            for x in stride(from: 0, to: w, by: 2) {
                let off = 4 * (y * w + x)
                let r = px[off]     >> 3   // 0‥31
                let g = px[off + 1] >> 3
                let b = px[off + 2] >> 3
                let key = UInt32(r) << 10 | UInt32(g) << 5 | UInt32(b)
                hist[key, default: 0] += 1
            }
        }
        
        // 4) Top N colours
        let sorted = hist.sorted { $0.value > $1.value }
        return sorted.prefix(maxCount).map { entry in
            let key = entry.key
            let r = CGFloat(((key >> 10) & 0x1F) << 3) / 255.0
            let g = CGFloat(((key >>  5) & 0x1F) << 3) / 255.0
            let b = CGFloat(( key        & 0x1F) << 3) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: 1.0)
        }
    }
    
    
    // -- ver 2. consider colors of marbles only --
    func marbleDominantColors(maxCount: Int = 3) -> [UIColor] {
        guard let view else { return [] }
        
        var hist: [UInt32: Int] = [:]
        
        // Iterate every marble (SKLabelNode with emoji)
        for node in marbles.values {
            guard let tex = view.texture(from: node) else { continue }
            
            let cg: CGImage
            if #available(iOS 17.0, *) {
                cg = tex.cgImage()
            } else {
                // fallback → texture → UIImage → cgImage
                guard let ui = tex.uiImage(), let cgImg = ui.cgImage else { continue }
                cg = cgImg
            }
            
            // Down-scale to 32×32 for speed
            let dim = 32
            guard let ctx = CGContext(data: nil,
                                      width: dim, height: dim,
                                      bitsPerComponent: 8,
                                      bytesPerRow: dim * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { continue }
            
            ctx.interpolationQuality = .low
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: dim, height: dim))
            guard let data = ctx.data else { continue }
            let px = data.bindMemory(to: UInt8.self, capacity: dim * dim * 4)
            
            // 5-bit RGB histogram (skip transparent pixels)
            for i in stride(from: 0, to: dim * dim, by: 2) {
                let off = i * 4
                let alpha = px[off + 3]
                if alpha < 200 { continue }               // ignore transparent bg
                
                let r = px[off]     >> 3
                let g = px[off + 1] >> 3
                let b = px[off + 2] >> 3
                let key = UInt32(r) << 10 | UInt32(g) << 5 | UInt32(b)
                hist[key, default: 0] += 1
            }
        }
        
        // Return top-N colours
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

// MARK: - SKTexture → UIImage helper (iOS 16- fallback)
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
