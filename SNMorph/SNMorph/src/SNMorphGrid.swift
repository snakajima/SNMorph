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
        let bytesPerRow = 4 * Int(size.width)
        let bytesOut = UnsafeMutablePointer<UInt8>(OpaquePointer(dataOut.mutableBytes))
        let bytesIn = UnsafePointer<UInt8>(OpaquePointer(dataIn.bytes))
        
        func update(gx:Int, gy:Int, dir:Int) {
            let p0 = handles[gx][gy]
            let p1 = handles[gx+dir][gy]
            let p2 = handles[gx][gy+dir]
            let d10 = p1.delta(from: p0)
            let d20 = p2.delta(from: p0)
            let k = d20.x * d10.y - d10.x * d20.y
            if k==0.0 {
                return
            }
            let d21 = p2.delta(from: p1)
            let d02 = p0.delta(from: p2)

            let origin:(x:Int, y:Int) = (Int(round(min(p0.x, p1.x, p2.x))), Int(round(min(p0.y, p1.y, p2.y))))
            let target:(x:Int, y:Int) = (Int(round(max(p0.x, p1.x, p2.x))), Int(round(max(p0.y, p1.y, p2.y))))
            for y in 0..<Int(target.y - origin.y) {
                var offset = bytesPerRow * (origin.y + y) + 4 * (origin.x)
                for x in 0..<(target.x - origin.x) {
                    let pt = CGPoint(x: CGFloat(origin.x + x), y: CGFloat(origin.y + y))
                    let d0 = pt.delta(from: p0)
                    if d10.crossProduct(with: d0) >= 0
                      && d21.crossProduct(with: pt.delta(from: p1)) >= 0
                      && d02.crossProduct(with: pt.delta(from: p2)) >= 0 {
                        let a = (d0.y * d20.x - d0.x * d20.y) / k
                        let b = (d0.x * d10.y - d0.y * d10.x) / k
                        let c = CGFloat(gx) + CGFloat(dir) * a
                        let d = CGFloat(gy) + CGFloat(dir) * b
                        let offsetIn = bytesPerRow * Int(round(cellSize.height * d)) + 4 * Int(round(cellSize.width * c))
                        bytesOut[offset] = bytesIn[offsetIn]
                        bytesOut[offset+1] = bytesIn[offsetIn+1]
                        bytesOut[offset+2] = bytesIn[offsetIn+2]
                        bytesOut[offset+3] = bytesIn[offsetIn+3]
                    }
                    offset += 4
                }
            }
        }
        update(gx: gx, gy: gy, dir: 1)
        update(gx: gx, gy: gy, dir: -1)
        update(gx: gx, gy: gy-1, dir: 1)
        update(gx: gx+1, gy: gy, dir: -1)
        update(gx: gx-1, gy: gy, dir: 1)
        update(gx: gx, gy: gy+1, dir: -1)
        
        updateImage()
    }
}
