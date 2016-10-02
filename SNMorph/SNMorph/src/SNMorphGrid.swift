//
//  SNMorphGrid.swift
//  SNMorph
//
//  Created by satoshi on 10/2/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

struct SNMorphGrid {
    var cgImage:CGImage?
    let slice:(x:Int, y:Int)
    let border:Int
    let gridX:Int, gridY:Int
    let cellSize:CGSize
    private let size:CGSize
    lazy private(set) var handles:[[CGPoint]] = {
        (0...self.gridX).map { (x) -> [CGPoint] in
            (0...self.gridY).map { (y) -> CGPoint in
                CGPoint(x: CGFloat(x) * self.cellSize.width,
                                    y: CGFloat(y) * self.cellSize.height)
            }
        }
    }()
    private let dataIn:NSData
    private let dataOut:NSMutableData
    private let dataMap:NSMutableData
    private let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
    init(image:UIImage, slice:(x:Int, y:Int), border:Int) {
        self.slice = slice
        self.border = border
        gridX = slice.x + border * 2
        gridY = slice.y + border * 2
        cellSize = CGSize(width: image.size.width / CGFloat(slice.x),
                          height: image.size.height / CGFloat(slice.y))
        size = CGSize(width:cellSize.width * CGFloat(gridX),
                                height:cellSize.height * CGFloat(gridY))
        let length = 4 * Int(size.width) * Int(size.height)
        let data = NSMutableData(length: length)!
        let context = CGContext(data: data.mutableBytes, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        
        let origin = CGPoint(x:cellSize.width * CGFloat(border), y:cellSize.height * CGFloat(border))
        context.draw(image.cgImage!, in: CGRect(origin: origin, size:image.size))
        dataIn = data
        dataOut = NSMutableData(length: length)!
        memcpy(dataOut.mutableBytes, dataIn.bytes, length)
        
        dataMap = NSMutableData(length: MemoryLayout<CGPoint>.size * Int(size.width) * Int(size.height))!
        let pmap = UnsafeMutablePointer<CGPoint>(OpaquePointer(dataMap.mutableBytes))
        for y in 0..<Int(size.width) {
            for x in 0..<Int(size.height) {
                pmap[y * Int(size.width) + x] = CGPoint(x: CGFloat(x) / cellSize.width, y:CGFloat(y) / cellSize.height)
            }
        }
        updateImage()
    }
    
    private mutating func updateImage() {
        let context = CGContext(data: dataOut.mutableBytes, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        cgImage = context.makeImage()
    }
    
    func map(pt:CGPoint) -> CGPoint {
        let pmap = UnsafeMutablePointer<CGPoint>(OpaquePointer(dataMap.mutableBytes))
        return pmap[Int(pt.y) * Int(size.width) + Int(pt.x)]
    }
    
    mutating func undateHandle(x:Int, y:Int, pt:CGPoint) {
        guard 0 < x && x < gridX && 0 < y && y < gridY else {
            return
        }
        handles[x][y] = pt
        updateGrid(x: x, y: y)
    }
    
    mutating func updateGrid(x:Int, y:Int) {
        let bytesOut = UnsafeMutablePointer<UInt8>(OpaquePointer(dataOut.mutableBytes))
        let bytesIn = UnsafePointer<UInt8>(OpaquePointer(dataIn.bytes))
        var nw = handles[x][y]
        var ne = handles[x+1][y]
        var sw = handles[x][y+1]
        var se = handles[x+1][y+1]
        let origin = CGPoint(x:min(nw.x, sw.x), y:min(nw.y, ne.y))
        let target = CGPoint(x:max(ne.x, se.x), y:max(sw.y, sw.y))
        nw = nw.translate(x: -origin.x,y: -origin.y)
        ne = ne.translate(x: -origin.x,y: -origin.y)
        sw = sw.translate(x: -origin.x,y: -origin.y)
        se = se.translate(x: -origin.x,y: -origin.y)
        for y in 0..<Int(target.y - origin.y) {
            var offset = 4 * Int(size.width) * (Int(origin.y) + y) + 4 * Int(origin.x)
            for x in 0..<Int(target.x - origin.x) {
                let pt = CGPoint(x: x, y: y)
                let d1 = pt.delta(from: nw)
                let d2 = se.delta(from: nw)
                if d1.crossProduct(with: d2) >= 0 {
                    bytesOut[offset] = 0
                    bytesOut[offset+1] = 0
                    bytesOut[offset+2] = 255
                    bytesOut[offset+3] = 128
                }
                offset += 4
            }
        }
        updateImage()
    }
}
