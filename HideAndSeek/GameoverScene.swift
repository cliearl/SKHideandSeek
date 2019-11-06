//
//  GameoverScene.swift
//  HideAndSeek
//
//  Created by Kyunghun Jung on 06/11/2019.
//  Copyright © 2019 qualitybits.net. All rights reserved.
//

import SpriteKit

class GameoverScene: SKScene {
    
    let clear: Bool
    let elapsedTime: Int
    
    init(size: CGSize, clear: Bool, elapsedTime: Int) {
        self.clear = clear
        self.elapsedTime = elapsedTime
        
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        showHighscore()
        showRank()
    }
    
    func showHighscore() {
        if let highscore = UserDefaults.standard.stringArray(forKey: "highscore") {
            let titleLabel = SKLabelNode(text: "High Score")
            titleLabel.fontName = "AvenirNext-Bold"
            titleLabel.fontSize = 54
            titleLabel.fontColor = .white
            titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
            self.addChild(titleLabel)
            
            for (i, score) in highscore.enumerated() {
                let scoreLabel = SKLabelNode(text: "\(i + 1): \(score)")
                scoreLabel.fontName = "AvenirNext-Bold"
                scoreLabel.fontSize = 65
                scoreLabel.fontColor = .white
                scoreLabel.position = CGPoint(x: size.width / 2, y: titleLabel.position.y * (CGFloat(i) * -0.07 + 0.9))
                self.addChild(scoreLabel)
            }
        } else {
            let titleLabel = SKLabelNode(text: "No High Score")
            titleLabel.fontName = "AvenirNext-Bold"
            titleLabel.fontSize = 54
            titleLabel.fontColor = .white
            titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
            self.addChild(titleLabel)
        }
    }
    
    func showRank() {
        let text: String = {
            if clear {
                if elapsedTime < 15 {
                    return "You are a special force or something"
                } else if elapsedTime < 30 {
                    return "You are a skilled survivor"
                } else {
                    return "You are just a novice"
                }
            } else {
                return "You died"
            }
        }()
        
        let rankLabel = SKLabelNode(text: text)
        rankLabel.fontName = "AvenirNext-Bold"
        rankLabel.fontSize = 55
        rankLabel.fontColor = .white
        rankLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
        self.addChild(rankLabel)
        
        let continueLabel = SKLabelNode(text: "Press anywhere to play again!")
        continueLabel.fontName = "AvenirNext-Bold"
        continueLabel.fontSize = 55
        continueLabel.fontColor = .white
        continueLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.2)
        self.addChild(continueLabel)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let gameScene = GameScene(size: CGSize(width: 2048, height: 2048))
        let transition = SKTransition.doorsOpenHorizontal(withDuration: 1.0)
        gameScene.scaleMode = .aspectFill
        view?.presentScene(gameScene, transition: transition)
    }
}
