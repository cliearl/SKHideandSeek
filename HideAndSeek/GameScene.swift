//
//  GameScene.swift
//  HideAndSeek
//
//  Created by Kyunghun Jung on 18/10/2019.
//  Copyright © 2019 qualitybits.net. All rights reserved.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - 초기 설정
    // 객체 컨테이너
    var obstacles = [SKSpriteNode]()
    var goal = SKSpriteNode()
    var player = SKSpriteNode()
    var enemies = [SKSpriteNode]()
    var enemyTimer = Timer()
    var enemyInterval: TimeInterval = 5.0

    var tileMap: SKTileMapNode!
    var playerSpeed: CGFloat = 160
    var enemySpeed: CGFloat = 50
    
    // 시스템 컨테이너
    let gridMap = SKNode()
    let cameraNode = SKCameraNode()
    let timeLabel = SKLabelNode(text: "0 sec")
    var lastUpdateTime: TimeInterval = -1
    var startTime = TimeInterval()
    var elapsedTime = 0 {
        didSet {
            timeLabel.text = "\(elapsedTime) sec"
        }
    }
    var touch: CGPoint? = nil
    var joystick = TLAnalogJoystick(withDiameter: 300)
    
    // 에이전트 시스템 가동용 컨테이너
    let agentSystem = GKComponentSystem(componentClass: GKAgent2D.self)
    let playerAgent = GKAgent2D()
    var enemyAgents = [GKAgent2D]()
    var polygonObstacles = [GKPolygonObstacle]()
    let ruleSystem = GKRuleSystem()
    
    var deltaTime: TimeInterval = 0
    let nodeSpeed = 5.0
    
    
    override func didMove(to view: SKView) {
        
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector.zero
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        
        setupMap()
        setupCamera()
        setupTimeLabel()
        setupRule()
        setupJoystick()
        createGoal()
        createPlayer()
        createObstacles()
//        createEnemy()
        
        enemyTimer = Timer.scheduledTimer(withTimeInterval: enemyInterval, repeats: true) { _ in
            self.createEnemy()
        }
    }
    
    
    // MARK: - 객체 셋업
    func setupMap() {
        gridMap.position = CGPoint(x: size.width / 2, y: size.height / 2)
        self.addChild(gridMap)
        
        // 기초정보 초기화
        guard let tileSet = SKTileSet(named: "Sample Grid Tile Set") else { return }
        let tileSize = CGSize(width: 128, height: 128)
        let columns = 16
        let rows = 16
        
        let sandTiles = tileSet.tileGroups.first { $0.name == "Sand" }
        let stoneTiles = tileSet.tileGroups.first { $0.name == "Cobblestone" }
        let waterTiles = tileSet.tileGroups.first { $0.name == "Water" }
        
        // 바닥 생성
        let bottomLayer = SKTileMapNode(tileSet: tileSet, columns: columns, rows: rows, tileSize: tileSize)
        bottomLayer.fill(with: sandTiles)
        bottomLayer.zPosition = Layer.mapBottom
        bottomLayer.lightingBitMask = 1
        gridMap.addChild(bottomLayer)
        
        // 탑 레이어 생성
        let topLayer = SKTileMapNode(tileSet: tileSet, columns: columns, rows: rows, tileSize: tileSize)
        topLayer.zPosition = Layer.mapTop
        topLayer.enableAutomapping = true
        topLayer.lightingBitMask = 1
        gridMap.addChild(topLayer)
        
        // 랜덤 맵 생성
        let source = GKPerlinNoiseSource()
        let random = GKARC4RandomSource().nextUniform()
        source.persistence = 1.0 + Double(round(random * 10) / 10)
        
        let noise = GKNoise(source)
        let size = vector2(1.0, 1.0)
        let origin = vector2(0.0, 0.0)
        let sampleCount = vector2(Int32(columns), Int32(rows))
        let noiseMap = GKNoiseMap(noise, size: size, origin: origin, sampleCount: sampleCount, seamless: true)
        
        for column in 0 ..< columns {
            for row in 0 ..< rows {
                let location = vector2(Int32(row), Int32(column))
                let terrainHeight = noiseMap.value(at: location)
                if terrainHeight >= 0 {
                    topLayer.setTileGroup(stoneTiles, forColumn: column, row: row)
                } else if terrainHeight < 0 {
                    topLayer.setTileGroup(waterTiles, forColumn: column, row: row)
                }
            }
        }
        
        self.tileMap = topLayer
    }
    
    func setupCamera() {
        self.camera = cameraNode
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        cameraNode.setScale(0.1)
        cameraNode.zPosition = Layer.camera
        self.addChild(cameraNode)
        
        let cameraScale = SKAction.scale(by: 5, duration: 1.5)
        cameraScale.timingMode = .easeInEaseOut
        cameraNode.run(cameraScale)
    }
    
    func setupTimeLabel() {
        timeLabel.fontName = "AppleGothic"
        timeLabel.fontSize = 60
        timeLabel.fontColor = SKColor.white
        timeLabel.horizontalAlignmentMode = .right
        timeLabel.position = CGPoint(x: 80, y: frame.midY - 100)
        cameraNode.addChild(timeLabel)
    }
    
    func setupRule() {
        self.ruleSystem.add([
            GKRule(predicate: NSPredicate(format: "$time != 0 && modulus:by:($time, 15) = 0"), assertingFact: NSString(string: "enemySpeed"), grade: 0.5),
            GKRule(predicate: NSPredicate(format: "$enemyCount > 10"), retractingFact: NSString(string: "enemySpeed"), grade: 0.1),
            GKRule(predicate: NSPredicate(format: "$enemyCount > 20"), retractingFact: NSString(string: "enemySpeed"), grade: 0.2)
            ]
        )
    }
    
    func setupJoystick() {
        joystick.baseImage = UIImage(named: "jSubstrate")
        joystick.handleImage = UIImage(named: "jStick")
        joystick.position = CGPoint(x: 0, y: -800)
        joystick.zPosition = Layer.upper
        cameraNode.addChild(joystick)
        
        self.touch = cameraNode.position
        
        // touches 콜백 대체
        joystick.on(.begin) { [weak self] _ in
            self?.touch?.x = (self?.player.position.x)! + (self?.joystick.velocity.x)!
            self?.touch?.y = (self?.player.position.y)! + (self?.joystick.velocity.y)!
        }
        
        joystick.on(.move) { [weak self] _ in
            self?.touch?.x = (self?.player.position.x)! + (self?.joystick.velocity.x)!
            self?.touch?.y = (self?.player.position.y)! + (self?.joystick.velocity.y)!
        }
    }
    
    func createGoal() {
        let texture = SpriteAtlas.textureNamed("goal")
        goal = SKSpriteNode(texture: texture)
        
        let position = [CGPoint(x: 0, y: 0),
                        CGPoint(x: size.width - goal.size.width, y: 0),
                        CGPoint(x: 0, y: size.height - goal.size.height),
                        CGPoint(x: size.width - goal.size.width,
                                y: size.height - goal.size.height)]
        let random = GKRandomDistribution(lowestValue: 0, highestValue: position.count - 1).nextInt()
        goal.anchorPoint = CGPoint.zero
        goal.position = position[random]
        goal.zPosition = Layer.object
        
        self.addChild(goal)
    }
    
    func createObstacles() {
        while obstacles.count < 10 {
            let texture = SpriteAtlas.textureNamed("obstacle")
            let obstacle = SKSpriteNode(texture: texture)
            let position = CGPoint(x: CGFloat(GKRandomDistribution(lowestValue: 64, highestValue: Int(size.width) - 64).nextInt()), y: CGFloat(GKRandomDistribution(lowestValue: 64, highestValue: Int(size.height) - 64).nextInt()))
            let isObstacleOverlapped = obstacles.contains {
                let dx = position.x - $0.position.x
                let dy = position.y - $0.position.y
                let distance = sqrt(dx*dx + dy*dy)
                if distance < obstacle.size.width * 2 {
                    return true
                }
                return false
            }
            
            let dx = position.x - player.position.x
            let dy = position.y - player.position.y
            let isPlayerOverlapped = sqrt(dx*dx + dy*dy) < player.size.width * 2
            if isObstacleOverlapped || isPlayerOverlapped { continue }
            
            obstacle.position = position
            obstacle.zPosition = Layer.object
            
            obstacle.lightingBitMask = 1
            obstacle.shadowCastBitMask = 1
            obstacle.shadowedBitMask = 1
            
            self.addChild(obstacle)
            obstacles.append(obstacle)
            
            
            let pos = obstacle.position
            let halfX = obstacle.size.width / 2
            let halfY = obstacle.size.height / 2
            let polygonObstacle = GKPolygonObstacle(points: [
                vector2(Float(pos.x - halfX), Float(pos.y + halfY)),
                vector2(Float(pos.x + halfX), Float(pos.y + halfY)),
                vector2(Float(pos.x + halfX), Float(pos.y - halfY)),
                vector2(Float(pos.x - halfX), Float(pos.y - halfY))
            ])
            polygonObstacles.append(polygonObstacle)
        }
    }
    
    func createPlayer() {
        let texture = SpriteAtlas.textureNamed("player")
        player = SKSpriteNode(texture: texture)
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        player.zPosition = Layer.player
        
        player.lightingBitMask = 1
        player.shadowCastBitMask = 1
        player.shadowedBitMask = 1
        
        player.physicsBody = SKPhysicsBody(texture: texture, size: texture.size())
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        
        self.addChild(player)
        
        self.listener = player
        let bgmPlayer = SKAudioNode(fileNamed: Sound.bgm)
        player.addChild(bgmPlayer)
        
        // 횃불 이펙트
        guard let fire = SKEmitterNode(fileNamed: "Fire") else { return }
        let fireEffect = SKEffectNode()
        fireEffect.position = CGPoint(x: -20, y: -30)
        fireEffect.zPosition = Layer.upper
        fireEffect.addChild(fire)
        player.addChild(fireEffect)
        
        // 광원효과
        let torchLight = SKLightNode()
        torchLight.position = CGPoint(x: -20, y: -30)
        torchLight.zPosition = Layer.light
        torchLight.falloff = 2
        torchLight.isEnabled = false
        player.addChild(torchLight)
        
        playerAgent.position = vector2(Float(player.position.x), Float(player.position.y))
        playerAgent.delegate = self
    }
    
    func createEnemy() {
        if enemies.count < 1 {
            let texture = SpriteAtlas.textureNamed("enemy")
            let enemy = SKSpriteNode(texture: texture)
            
            var isPlayerOverlapped = false
            repeat {
                let position = CGPoint(x: CGFloat(GKRandomDistribution(lowestValue: 100, highestValue: Int(size.width) - 100).nextInt()), y: CGFloat(GKRandomDistribution(lowestValue: 100, highestValue: Int(size.height) - 100).nextInt()))
                let dx = position.x - player.position.x
                let dy = position.y - player.position.y
                isPlayerOverlapped = sqrt(dx*dx - dy*dy) < player.size.width * 2
                
                enemy.position = position
            } while isPlayerOverlapped
            
            enemy.zPosition = Layer.enemy
            enemy.physicsBody = SKPhysicsBody(rectangleOf: texture.size())
            enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
            
            enemy.lightingBitMask = 1
            enemy.shadowCastBitMask = 1
            enemy.shadowedBitMask = 1
            
            enemies.append(enemy)
            self.addChild(enemy)
            
            let audioNode = SKAudioNode(fileNamed: Sound.enemy)
            enemy.addChild(audioNode)
            
            // GKAgent 셋업
            let enemyAgent = GKAgent2D()
            enemyAgent.maxAcceleration = 100
            enemyAgent.maxSpeed = 50
            enemyAgent.position = vector2(Float(enemy.position.x), Float(enemy.position.y))
            enemyAgent.delegate = self
            
            enemyAgent.behavior = GKBehavior(goals: [
                GKGoal(toWander: 1.0),
                GKGoal(toSeekAgent: playerAgent),
                GKGoal(toAvoid: polygonObstacles, maxPredictionTime: 0.1)
                ], andWeights: [NSNumber(value: 10.0), NSNumber(value: 0.01), NSNumber(value: 100.0)]
            )
            
            enemyAgents.append(enemyAgent)
            agentSystem.addComponent(enemyAgent)
        }
    }
    
    
    // MARK: - 객체 움직임
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        touch = touches.first?.location(in: self)
//    }
//    
//    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        touch = touches.first?.location(in: self)
//    }
    
    func updatePlayer() {
        guard let touchPosition = touch else { return }
        let currentPosition = player.position
        if shouldMove(currentPosition: currentPosition, touchPosition: touchPosition) {
            moveObject(for: player, to: touchPosition, speed: playerSpeed)
        } else {
            player.physicsBody?.isResting = true
        }
    }
    
    func shouldMove(currentPosition: CGPoint, touchPosition: CGPoint) -> Bool {
        return abs(currentPosition.x - touchPosition.x) > player.size.width / 4 || abs(currentPosition.y - touchPosition.y) > player.size.height / 4
    }
    
    func moveObject(for sprite: SKSpriteNode, to target: CGPoint, speed: CGFloat) {
        let angle = atan2(target.y - sprite.position.y,
                          target.x - sprite.position.x)
        let rotateAction = SKAction.rotate(toAngle: angle + (CGFloat.pi / 2), duration: 0.1)
        sprite.run(rotateAction)
        
        let velocityX = speed * cos(angle)
        let velocityY = speed * sin(angle)
        let newVelocity = CGVector(dx: velocityX, dy: velocityY)
        sprite.physicsBody?.velocity = newVelocity
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        if (self.lastUpdateTime < 0) {
            self.lastUpdateTime = currentTime
            self.startTime = currentTime
        }
        deltaTime = currentTime - self.lastUpdateTime
        self.lastUpdateTime = currentTime
        self.elapsedTime = Int(lastUpdateTime - startTime)
        
        
        // 룰 시스템 평가
        ruleSystem.state["time"] = elapsedTime
        ruleSystem.state["enemyCount"] = enemies.count
        ruleSystem.reset()
        ruleSystem.evaluate()
        let speed = ruleSystem.grade(forFact: NSString(string: "enemySpeed"))
        enemySpeed += CGFloat(speed)
//        print(enemySpeed)
        
        
        // 맵 형태에 따른 스피드 변경
        let position = CGPoint(x: player.position.x - size.width / 2,
                               y: player.position.y - size.height / 2)
        let column = tileMap.tileColumnIndex(fromPosition: position)
        let row = tileMap.tileRowIndex(fromPosition: position)
        let tile = tileMap.tileDefinition(atColumn: column, row: row)
        if tile == nil {
//            print("sand")
            playerSpeed = 100
        } else if (tile?.name?.contains("Water"))! {
//            print("water")
            playerSpeed = 40
        } else if (tile?.name?.contains("Cobblestone"))! {
//            print("stone")
            playerSpeed = 160
        }
//        print(playerSpeed)
        
        updatePlayer()
        playerAgent.position = vector2(Float(player.position.x), Float(player.position.y))
        
        agentSystem.update(deltaTime: CFTimeInterval(deltaTime * nodeSpeed))
        
        cameraNode.position = player.position
        cameraNode.run(SKAction.move(to: CGPoint(x: player.position.x, y: player.position.y), duration: 0.2))
    }
}

extension GameScene: GKAgentDelegate {
    func agentDidUpdate(_ agent: GKAgent) {
        if let agent = agent as? GKAgent2D,
            let index = enemyAgents.firstIndex(where: { $0 == agent }) {
            let enemy = enemies[index]
            let position = CGPoint(x: CGFloat(agent.position.x), y: CGFloat(agent.position.y))
            moveObject(for: enemy, to: position, speed: enemySpeed)
        }
    }
}
