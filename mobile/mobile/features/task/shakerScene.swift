//
//  shakerScene.swift
//  mobile
//

import SpriteKit
import CoreMotion

final class shakerScene: SKScene {

    // MARK: - Motion
    private let motion = CMMotionManager()
    private var isMotionOn = false

    // filter
    private var filteredGravity = CGVector.zero
    private let gAlpha:  CGFloat = 0.8   // gravity LPF
    private let accScale: CGFloat = 400  // shaking force scale

    // MARK: - Gravity presets
    private let airGravity = CGVector(dx: 0, dy: -10)    // (OFF mode) gravity
    private let oilGravityScale:  CGFloat = 2.5          // (ON mode) gravity

    // MARK: - Edge-loop inset
    private let inset: CGFloat = 14
    private let lidHeight: CGFloat = 0

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
            let ax = abs(ua.x) > 0.02 ? ua.x : 0
            let ay = abs(ua.y) > 0.02 ? ua.y : 0
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
        let spawnY =  size.height/2 - margin*2 - lidHeight

        let node = SKLabelNode(fontNamed: "AppleColorEmoji")
        node.text = symbol
        node.fontSize = 57
        node.verticalAlignmentMode = .center
        node.position = CGPoint(x: spawnX, y: spawnY)
        node.zPosition = 50

        //let radius: CGFloat = 27
        node.physicsBody = makeBody()
        addChild(node)
    }

    // MARK: - Helpers
    /// Returns a circular physics body with parameters depending on current mode.
    private func makeBody() -> SKPhysicsBody {
        let body = SKPhysicsBody(circleOfRadius: 27)
        body.usesPreciseCollisionDetection = true
        if isMotionOn {
            body.restitution = 0.5
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
