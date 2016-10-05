//
//  SNMorphEditController.swift
//  SNMorph
//
//  Created by satoshi on 10/1/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class SNMorphEditController: UIViewController {
    public var grid:SNMorphGrid!
    
    private let viewMain = UIView()

    private var xform = CGAffineTransform.identity
    private var layers = [[CALayer]]()

    // Transient properties for handlePinch
    private var anchor = CGPoint.zero
    private var delta = CGPoint.zero

    // Transient properties for handlePan
    private var handle:(layer:CALayer, x:Int, y:Int)?
    private var isInBound:((CGPoint)->Bool) = { _ in
        return false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let xf = CGAffineTransform.init(translationX: (view.frame.size.width-grid.size.width)/2, y: (view.frame.size.height-grid.size.height)/2)
        let scale = min(view.frame.size.width / grid.size.width, view.frame.size.height / grid.size.height)
        xform = xf.scaledBy(x: scale, y: scale)
        viewMain.transform = xform
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewMain.frame = CGRect(origin: .zero, size: grid.size)
        view.addSubview(viewMain)

        viewMain.layer.contentsGravity = kCAGravityBottomLeft
        viewMain.layer.contents = grid.cgImage
        viewMain.layer.backgroundColor = UIColor.white.cgColor
        
        let handleSize = CGSize(width: grid.cellSize.width/6.0, height: grid.cellSize.width/6.0)
        layers = (0...grid.gridX).map { (x) -> [CALayer] in
            (0...grid.gridY).map { (y) -> CALayer in
                let layer = CALayer()
                let origin = grid.handles[x][y].translate(x: -handleSize.width/2.0, y: -handleSize.height/2.0)
                layer.frame = CGRect(origin: origin, size: handleSize)
                layer.cornerRadius = handleSize.width/2.0
                layer.masksToBounds = true
                layer.backgroundColor = UIColor.magenta.cgColor
                viewMain.layer.addSublayer(layer)
                return layer
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
        switch(recognizer.state) {
        case .began:
            let pos = grid.map(pt: ptMain)
            print("pan", pos)
            let x = Int(round(pos.x)), y = Int(round(pos.y))
            if 0 < x && x < grid.gridX && 0 < y && y < grid.gridY {
                handle = (layer:layers[x][y], x:x, y:y)
                isInBound = grid.boundChecker(x: x, y: y)
            }
            break
        case .changed:
            if let handle = handle, isInBound(ptMain) {
                var rc = handle.layer.frame
                rc.origin = ptMain.translate(x: -rc.size.width/2.0, y: -rc.size.height/2.0)
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.0)
                handle.layer.frame = rc
                CATransaction.commit()
                grid.undateHandle(x: handle.x, y: handle.y, pt: ptMain)
                viewMain.layer.contents = grid.cgImage
            }
        case .ended:
            handle = nil
        default:
            handle = nil
        }
    }
}
