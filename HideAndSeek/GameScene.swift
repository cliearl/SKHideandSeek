//
//  GameScene.swift
//  HideAndSeek
//
//  Created by Kyunghun Jung on 18/10/2019.
//  Copyright © 2019 qualitybits.net. All rights reserved.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
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
    
    override func didMove(to view: SKView) {
        setupMap()
        setupCamera()
        setupTimeLabel()
    }
    
    func setupMap() {
        gridMap.position = CGPoint(x: size.width / 2, y: size.height / 2)
        self.addChild(gridMap)
        
        // 기초정보 초기화
        guard let tileSet = SKTileSet(named: "Sample Grid Tile Set") else { return }
        let tileSize = CGSize(width: 128, height: 128)
        let columns = 12
        let rows = 16
        
        let sandTiles = tileSet.tileGroups.first { $0.name == "Sand" }
        let stoneTiles = tileSet.tileGroups.first { $0.name == "Cobblestone" }
        let waterTiles = tileSet.tileGroups.first { $0.name == "Water" }
        
        // 바닥 생성
        let bottomLayer = SKTileMapNode(tileSet: tileSet, columns: columns, rows: rows, tileSize: tileSize)
        bottomLayer.fill(with: sandTiles)
        bottomLayer.zPosition = Layer.mapBottom
        gridMap.addChild(bottomLayer)
        
        // 탑 레이어 생성
        let topLayer = SKTileMapNode(tileSet: tileSet, columns: columns, rows: rows, tileSize: tileSize)
        topLayer.zPosition = Layer.mapTop
        topLayer.enableAutomapping = true
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
    
    override func update(_ currentTime: TimeInterval) {
        if (self.lastUpdateTime < 0) {
            self.lastUpdateTime = currentTime
            self.startTime = currentTime
        }
        self.lastUpdateTime = currentTime
        self.elapsedTime = Int(lastUpdateTime - startTime)
    }
}
