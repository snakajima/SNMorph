//
//  SNMorphEditController.swift
//  SNMorph
//
//  Created by satoshi on 10/1/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

// from SNDraw
private extension CGPoint {
    func delta(from:CGPoint) -> CGPoint {
        return CGPoint(x: self.x - from.x, y: self.y - from.y)
    }
}

class SNMorphEditController: UIViewController {
    public var grid:SNMorphGrid!
    
    @IBOutlet var viewMain:UIView!

    private var xform = CGAffineTransform.identity
    private var handles = [CALayer]()

    // Transient properties for handlePinch
    private var anchor = CGPoint.zero
    private var delta = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()

        viewMain.layer.contentsGravity = kCAGravityBottomLeft
        viewMain.layer.contents = grid.cgImage
        
        let handleSize = CGSize(width: grid.cellSize.width/6.0, height: grid.cellSize.width/6.0)
        for y in 0...grid.gridY {
            for x in 0...grid.gridX {
                let layer = CALayer()
                let origin = CGPoint(x: CGFloat(x) * grid.cellSize.width - handleSize.width/2.0,
                                    y: CGFloat(y) * grid.cellSize.height - handleSize.width/2.0)
                layer.frame = CGRect(origin: origin, size: handleSize)
                layer.cornerRadius = handleSize.width/2.0
                layer.masksToBounds = true
                layer.backgroundColor = UIColor.magenta.cgColor
                handles.append(layer)
                viewMain.layer.addSublayer(layer)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func handlePinch(recognizer:UIPinchGestureRecognizer) {
        let ptMain = recognizer.location(in: viewMain)
        let ptView = recognizer.location(in: view)

        switch(recognizer.state) {
        case .began:
            anchor = ptView
            delta = ptMain.delta(from: viewMain.center)
        case .changed:
            if recognizer.numberOfTouches == 2 {
                var offset = ptView.delta(from: anchor)
                offset.x /= xform.a
                offset.y /= xform.a
                var xf = xform.translatedBy(x: offset.x + delta.x, y: offset.y + delta.y)
                xf = xf.scaledBy(x: recognizer.scale, y: recognizer.scale)
                xf = xf.translatedBy(x: -delta.x, y: -delta.y)
                self.viewMain.transform = xf
            }
        case .ended:
            xform = self.viewMain.transform
        default:
            self.viewMain.transform = xform
        }
    }
    
    @IBAction func handlePan(recognizer:UIPanGestureRecognizer) {
        let ptMain = recognizer.location(in: viewMain)
        print("pan", grid.map(pt: ptMain))
    }
}
