//
//  Constants.swift
//  HideAndSeek
//
//  Created by Kyunghun Jung on 18/10/2019.
//  Copyright © 2019 qualitybits.net. All rights reserved.
//

import SpriteKit

let SpriteAtlas = SKTextureAtlas(named: "Sprites")

struct Layer {
    static let mapBottom: CGFloat = 0
    static let mapTop: CGFloat = 1
    static let object: CGFloat = 2
    static let camera: CGFloat = 20
}
