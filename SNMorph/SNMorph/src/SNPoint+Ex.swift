//
//  SNPoint.swift
//  SNMorph
//
//  Created by satoshi on 8/5/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

extension CGPoint {
    func middle(from:CGPoint) -> CGPoint {
        return CGPoint(x: (self.x + from.x)/2, y: (self.y + from.y)/2)
    }

    func delta(from:CGPoint) -> CGPoint {
        return CGPoint(x: self.x - from.x, y: self.y - from.y)
    }
    
    func dotProduct(with:CGPoint) -> CGFloat {
        return self.x * with.x + self.y * with.y
    }

    func crossProduct(with:CGPoint) -> CGFloat {
        return self.x * with.y - self.y * with.x
    }
    
    func distance2(from:CGPoint) -> CGFloat {
        let delta = self.delta(from: from)
        return delta.dotProduct(with: delta)
    }
    
    func distance(from:CGPoint) -> CGFloat {
        return sqrt(self.distance2(from: from))
    }

    func translate(x:CGFloat, y:CGFloat) -> CGPoint {
        return CGPoint(x: self.x + x, y: self.y + y)
    }
}
