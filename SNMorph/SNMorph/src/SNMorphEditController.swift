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
    // Transient properties for handlePinch
    private var anchor = CGPoint.zero
    private var delta = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()

        viewMain.layer.contentsGravity = kCAGravityCenter
        viewMain.layer.contents = grid.cgImage
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
}
