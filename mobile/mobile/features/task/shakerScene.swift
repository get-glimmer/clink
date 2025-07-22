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

final class ShakerScene: SKScene {

    // MARK: - Motion & Storage
    private let motion = CMMotionManager()
    private var filteredGravity = CGVector.zero
    private let gAlpha:  CGFloat = 0.2   // gravity LPF
    private let accScale: CGFloat = 600  // shaking force scale
    private let oilGravityScale:  CGFloat = 10          // gravity when shaker is on

    // Storage for marbles keyed by Task UUID
    private var marbles: [UUID: SKLabelNode] = [:]

    // MARK: - Edge-loop inset
    private let inset: CGFloat = 12
    private let lidHeight: CGFloat = 40

    // init starts motion immediately
    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = .init(x: 0.5, y: 0.5)
        startMotion()         // shaker always active
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
    }

    // MARK: - Motion handlers (always on)
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
            self.physicsWorld.gravity = CGVector(dx: self.filteredGravity.dx * self.oilGravityScale,
                                                  dy: self.filteredGravity.dy * self.oilGravityScale)
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

    // MARK: - Public API
    /// Drops an emoji into the scene identified by taskId. If already exists it will be ignored.
    func addEmoji(_ symbol: String, for taskId: UUID) {
        guard marbles[taskId] == nil else { return }
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
        marbles[taskId] = node
    }

    /// Removes the emoji associated with taskId if present.
    func removeEmoji(for taskId: UUID) {
        guard let node = marbles[taskId] else { return }
        node.removeFromParent()
        marbles.removeValue(forKey: taskId)
    }

    /// Clears all emojis (used when the entire task list resets)
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
        return body
    }
}
