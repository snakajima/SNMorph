//
//  SNMorphGrid.swift
//  SNMorph
//
//  Created by satoshi on 10/2/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

struct SNMorphGrid {
    let image:UIImage
    let slice:(x:Int, y:Int)
    let border:Int
    private let gridX:Int, gridY:Int
    private let gridSize:CGSize
    private let outerImageSize:CGSize
    init(image:UIImage, slice:(x:Int, y:Int), border:Int) {
        self.image = image
        self.slice = slice
        self.border = border
        gridX = slice.x + border * 2
        gridY = slice.y + border * 2
        gridSize = CGSize(width: image.size.width / CGFloat(slice.x),
                          height: image.size.width / CGFloat(slice.y))
        outerImageSize = CGSize(width:gridSize.width * CGFloat(gridX),
                                height:gridSize.height * CGFloat(gridX))
    }
}
