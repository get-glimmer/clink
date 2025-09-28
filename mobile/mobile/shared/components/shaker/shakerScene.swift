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
    
    // Callback for when notes emoji is tapped
    var onNotesEmojiTapped: (() -> Void)?
    
    // Custom boundary configuration for friend shakers
    private var customInset: CGFloat?
    private var customLidHeight: CGFloat?
    private var customBottomExtra: CGFloat?
    // Emoji size scaling (1.0 = default)
    private var emojiScaleFactor: CGFloat = 1.0
    
    // MARK: - Edge-loop inset
    private let inset: CGFloat = 12
    private let lidHeight: CGFloat = 40
    // Cached floor Y (inside edge loop)
    private var computedFloorY: CGFloat = 0
    
    // MARK: - Visual tuning
    // Natural, stronger glow for emoji reactions
    private let glowBlurRadius: CGFloat = 16.0
    private let glowAlpha: CGFloat = 0.85
    
    // MARK: - Haptic settings
    var isHapticsEnabled: Bool = true
    private var lastHapticTime: TimeInterval = 0
    private let hapticCooldown: TimeInterval = 0.25
    private let hapticImpulseThreshold: CGFloat = 1.0
    
    // control haptics visibility-wise
    func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
    }
    
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
        setupPhysicsBoundaries()
    }
    
    // MARK: - Boundary Configuration
    func configureBoundaries(inset: CGFloat, lidHeight: CGFloat) {
        configureBoundaries(inset: inset, lidHeight: lidHeight, bottomExtraDepth: 0)
    }

    // Allows extending the physics floor downward by `bottomExtraDepth` points (preview tiles)
    func configureBoundaries(inset: CGFloat, lidHeight: CGFloat, bottomExtraDepth: CGFloat) {
        customInset = inset
        customLidHeight = lidHeight
        customBottomExtra = max(0, bottomExtraDepth)
        setupPhysicsBoundaries()
    }

    // Adjust emoji scale for preview tiles vs detail
    func setEmojiScale(_ factor: CGFloat) {
        emojiScaleFactor = max(0.5, min(factor, 1.5))
    }
    
    private func setupPhysicsBoundaries() {
        let usedInset = customInset ?? inset
        let usedLidHeight = customLidHeight ?? lidHeight
        let extra = customBottomExtra ?? 0
        
        /* ----- edge-loop smaller than PNG ----- */
        // Extend height by `extra` and shift rect down by the same amount to lower the floor
        let rect = CGRect(x: -size.width/2  + usedInset,
                          y: -size.height/2 + usedInset - extra,
                          width:  size.width  - usedInset*2,
                          height: size.height - usedInset*2 - usedLidHeight + extra)
        let wall = SKPhysicsBody(edgeLoopFrom: rect)
        wall.friction = 0
        wall.isDynamic = false
        wall.categoryBitMask = 0x1 << 1       // jar wall
        wall.contactTestBitMask = 0x1 << 0    // detect marble-wall contact
        physicsBody   = wall

        // Cache floor Y for settling helpers (add radius when used)
        computedFloorY = rect.minY
    }
    
    // MARK: - Motion handlers
    func setMotionEnabled(_ enabled: Bool) {
        guard enabled != motionEnabled else { return }
        motionEnabled = enabled
        if enabled {
            startMotion()
        } else {
            stopMotion()
            // Fallback: ensure a constant downward gravity so marbles fall
            physicsWorld.gravity = CGVector(dx: 0, dy: -gravityScale)
        }
    }
    
    private func startMotion() {
        guard motion.isDeviceMotionAvailable else {
            // Device motion unavailable (e.g., Simulator/preview) → use constant gravity
            physicsWorld.gravity = CGVector(dx: 0, dy: -gravityScale)
            return
        }
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

    // Explicit constant downward gravity (used for previews)
    func useConstantGravity(_ strength: CGFloat) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -abs(strength))
    }

    // Force-settle all marbles to the bottom (useful for small preview tiles)
    func settleAllToBottom() {
        let radius: CGFloat = 25.6
        let floor = computedFloorY + radius + 1
        for (_, node) in marbles {
            if node.position.y > floor {
                node.position.y = floor
                node.physicsBody?.velocity = .zero
                node.physicsBody?.angularVelocity = 0
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
        let margin: CGFloat = 14 * emojiScaleFactor
        let minX = -size.width/2 + margin*2
        let maxX =  size.width/2 - margin*2
        let spawnX = CGFloat.random(in: minX...maxX)
        let spawnY =  size.height/2 - margin*2 - lidHeight - margin*(CGFloat.random(in: 2...3))
        
        let node = SKLabelNode(fontNamed: "AppleColorEmoji")
        node.text = symbol
        node.fontSize = 54 * emojiScaleFactor
        node.verticalAlignmentMode = .center
        node.position = CGPoint(x: spawnX, y: spawnY)
        node.zPosition = 50
        node.physicsBody = makeBody()
        addChild(node)
        marbles[taskId] = node
    }
    
    // Drops a glowing emoji reaction into the scene with special effects
    func addGlowingEmoji(_ symbol: String, for taskId: UUID) {
        guard marbles[taskId] == nil else { return }
        let margin: CGFloat = 14 * emojiScaleFactor
        let minX = -size.width/2 + margin*2
        let maxX =  size.width/2 - margin*2
        let spawnX = CGFloat.random(in: minX...maxX)
        let spawnY =  size.height/2 - margin*2 - lidHeight - margin*(CGFloat.random(in: 2...3))
        
        let node = SKLabelNode(fontNamed: "AppleColorEmoji")
        node.text = symbol
        node.fontSize = 54 * emojiScaleFactor // match regular size; no enlargement
        node.verticalAlignmentMode = .center
        node.position = CGPoint(x: spawnX, y: spawnY)
        node.zPosition = 55 // Higher than regular emojis
        node.physicsBody = makeBody()
        // Mark as reaction so we can identify later
        node.name = "reaction"
        
        // Revert to effect-node based blur (natural halo) but force yellow tint
        let glowEffect = SKEffectNode()
        glowEffect.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": glowBlurRadius])
        glowEffect.shouldRasterize = true
        glowEffect.zPosition = -1
        glowEffect.alpha = glowAlpha

        // Yellow-tinted duplicate of the emoji (small scale so it doesn't look like a disk)
        let glowLabel = SKLabelNode(fontNamed: "AppleColorEmoji")
        glowLabel.text = symbol
        glowLabel.fontSize = node.fontSize
        glowLabel.verticalAlignmentMode = .center
        glowLabel.setScale(1.1)
        // Remove forced tint so system emoji hue drives the glow (more natural)
        glowLabel.colorBlendFactor = 0.0

        glowEffect.addChild(glowLabel)
        node.addChild(glowEffect)
        
        addChild(node)
        
        // Ensure no pulsing/thumping animations are applied
        node.removeAllActions()
        node.setScale(1.0)
        
        marbles[taskId] = node
    }
    
    // Updates the emoji text for an existing marble without resetting physics.
    func updateEmoji(_ symbol: String, for taskId: UUID) {
        guard let node = marbles[taskId] else { return }
        guard node.text != symbol else { return }
        node.text = symbol
        
        // animation
        //        let up = SKAction.scale(to: 1.2, duration: 0.08)
        //        let down = SKAction.scale(to: 1.0, duration: 0.10)
        //        node.run(.sequence([up, down]))
    }
    
    // Removes the emoji associated with taskId if present.
    func removeEmoji(for taskId: UUID) {
        guard let node = marbles[taskId] else { return }
        node.removeFromParent()
        marbles.removeValue(forKey: taskId)
    }
    
    // Removes one occurrence of an emoji by its symbol (first match)
    func removeEmoji(symbol: String) {
        if let match = marbles.first(where: { $0.value.text == symbol }) {
            match.value.removeFromParent()
            marbles.removeValue(forKey: match.key)
        }
    }

    // Checks whether a REACTION emoji with the given symbol exists
    func hasReactionEmoji(_ symbol: String) -> Bool {
        return marbles.values.contains { $0.name == "reaction" && $0.text == symbol }
    }

    // Removes one REACTION emoji by its symbol (first match among reaction nodes only)
    func removeReactionEmoji(symbol: String) {
        if let match = marbles.first(where: { $0.value.name == "reaction" && $0.value.text == symbol }) {
            match.value.removeFromParent()
            marbles.removeValue(forKey: match.key)
        }
    }
    
    // Clears all emojis (used when the entire task list resets)
    func resetScene() {
        for (_, node) in marbles { node.removeFromParent() }
        marbles.removeAll()
    }
    
    // Checks whether an emoji with the given symbol already exists in the scene
    func hasEmoji(_ symbol: String) -> Bool {
        return marbles.values.contains { $0.text == symbol }
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
    
    // Procedural soft radial glow texture (1.0 center → 0 at edge)
    private func makeRadialGlowTexture(diameter: CGFloat, color: UIColor) -> SKTexture {
        let size = Int(max(16, diameter.rounded()))
        let w = size, h = size
        let bytesPerRow = w * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: w * h * 4)
        defer { data.deallocate() }
        
        let center = CGPoint(x: CGFloat(w - 1) / 2, y: CGFloat(h - 1) / 2)
        let maxR = min(center.x, center.y)
        
        var rC: CGFloat = 1, gC: CGFloat = 1, bC: CGFloat = 0, aC: CGFloat = 1
        color.getRed(&rC, green: &gC, blue: &bC, alpha: &aC)
        
        for y in 0..<h {
            for x in 0..<w {
                let dx = CGFloat(x) - center.x
                let dy = CGFloat(y) - center.y
                let d = sqrt(dx*dx + dy*dy)
                let t = min(max(d / maxR, 0), 1) // 0..1
        // Steeper falloff so edge fades quickly and center stays soft
        let falloff = max(0, pow(1 - t, 2.5))
                let alpha = UInt8((falloff * 255).rounded())
                let off = (y * w + x) * 4
                data[off + 0] = UInt8((rC * 255).rounded())
                data[off + 1] = UInt8((gC * 255).rounded())
                data[off + 2] = UInt8((bC * 255).rounded())
                data[off + 3] = alpha
            }
        }
        guard let ctx = CGContext(data: data,
                                  width: w,
                                  height: h,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg = ctx.makeImage() else {
            return SKTexture()
        }
        return SKTexture(cgImage: cg)
    }
    
    // MARK: - Contact delegate
    func didBegin(_ contact: SKPhysicsContact) {
      guard isHapticsEnabled else { return }

      // Ignore very small, invisible jitters
      let impulse = contact.collisionImpulse
      guard impulse > hapticImpulseThreshold else { return }

      let now = CACurrentMediaTime()
      guard now - lastHapticTime > hapticCooldown else { return }

      let normalized = min(max(impulse / 10.0, 0.0), 1.0)
      let gen = UIImpactFeedbackGenerator(style: .medium)
      gen.impactOccurred(intensity: normalized)

      lastHapticTime = now
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
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodesAtPoint = nodes(at: location)
        
        // Check if any touched node is a notes emoji
        for node in nodesAtPoint {
            if let labelNode = node as? SKLabelNode,
               labelNode.text == "🗒️" {
                onNotesEmojiTapped?()
                break
            }
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
