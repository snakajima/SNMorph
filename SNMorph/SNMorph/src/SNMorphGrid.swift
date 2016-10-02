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
    
    mutating func updateGrid(x gx:Int, y gy:Int) {
        let bytesOut = UnsafeMutablePointer<UInt8>(OpaquePointer(dataOut.mutableBytes))
        let bytesIn = UnsafePointer<UInt8>(OpaquePointer(dataIn.bytes))
        var nw = handles[gx][gy]
        var ne = handles[gx+1][gy]
        var sw = handles[gx][gy+1]
        var se = handles[gx+1][gy+1]
        let origin = CGPoint(x:min(nw.x, sw.x), y:min(nw.y, ne.y))
        let target = CGPoint(x:max(ne.x, se.x), y:max(sw.y, sw.y))
        nw = nw.delta(from: origin)
        ne = ne.delta(from: origin)
        sw = sw.delta(from: origin)
        se = se.delta(from: origin)
        let dne = ne.delta(from: nw)
        let dsw = sw.delta(from: nw)
        let dse = se.delta(from: nw)
        let x1 = dne.x, y1 = dne.y
        let x2 = dse.x, y2 = dse.y
        let x3 = dsw.x, y3 = dsw.y
        let k1 = x2 * y1 - x1 * y2
        let k2 = x3 * y2 - x2 * y3
        guard k1 != 0.0 && k2 != 0.0 else {
            return
        }
        let bytesPerRow = 4 * Int(size.width)
        for y in 0..<Int(target.y - origin.y) {
            var offset = bytesPerRow * (Int(origin.y) + y) + 4 * Int(origin.x)
            for x in 0..<Int(target.x - origin.x) {
                let pt = CGPoint(x: x, y: y).delta(from: nw)
                let p = pt.x, q = pt.y
                if pt.crossProduct(with: dse) >= 0 {
                    let b = cellSize.width * (CGFloat(gy) + (p * y1 - q * x1) / k1)
                    let a = cellSize.height * (CGFloat(gx) + (q * x2 - p * y2) / k1)
                    //print("a,b", x, y, a, b)
                    let offsetIn = bytesPerRow * Int(b) + 4 * Int(a)
                    bytesOut[offset] = bytesIn[offsetIn]
                    bytesOut[offset+1] = bytesIn[offsetIn+1]
                    bytesOut[offset+2] = bytesIn[offsetIn+2]
                    bytesOut[offset+3] = bytesIn[offsetIn+3]
                } else {
                    let b = cellSize.width * (CGFloat(gy) + (p * y2 - q * x2) / k2)
                    let a = cellSize.height * (CGFloat(gx) + (q * x3 - p * y3) / k2)
                    // print("a,b", x, y, a, b)
                    let offsetIn = bytesPerRow * Int(b) + 4 * Int(a)
                    bytesOut[offset] = bytesIn[offsetIn]
                    bytesOut[offset+1] = bytesIn[offsetIn+1]
                    bytesOut[offset+2] = bytesIn[offsetIn+2]
                    bytesOut[offset+3] = bytesIn[offsetIn+3]
                }
                offset += 4
            }
        }
        updateImage()
    }
}
