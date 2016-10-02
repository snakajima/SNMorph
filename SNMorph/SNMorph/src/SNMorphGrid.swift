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

        let p0 = handles[gx][gy]
        let ptN = handles[gx][gy-1]
        let ptS = handles[gx][gy+1]
        let ptW = handles[gx-1][gy]
        let ptE = handles[gx+1][gy]
        struct Matrix4 {
            let x0:CGFloat
            let x1:CGFloat
            let y0:CGFloat
            let y1:CGFloat
        }
        func process(p1:CGPoint, p2:CGPoint, matrix:Matrix4) {
            let origin = CGPoint(x:round(min(p0.x, p1.x, p2.x)), y:round(min(p0.y, p1.y, p2.y)))
            let target = CGPoint(x:round(max(p0.x, p1.x, p2.x)), y:round(max(p0.y, p1.y, p2.y)))
            let d10 = p1.delta(from: p0)
            let d20 = p2.delta(from: p0)
            let k = d20.x * d10.y - d10.x * d20.y
            let d21 = p2.delta(from: p1)
            let d02 = p0.delta(from: p2)
            for y in 0..<Int(target.y - origin.y) {
                var offset = bytesPerRow * (Int(origin.y) + y) + 4 * Int(origin.x)
                for x in 0..<Int(target.x - origin.x) {
                    let pt = origin.translate(x: CGFloat(x), y: CGFloat(y))
                    let d0 = pt.delta(from: p0)
                    if d10.crossProduct(with: d0) >= 0
                      && d21.crossProduct(with: pt.delta(from: p1)) >= 0
                      && d02.crossProduct(with: pt.delta(from: p2)) >= 0 {
                        let a = (d0.y * d20.x - d0.x * d20.y) / k
                        let b = (d0.x * d10.y - d0.y * d10.x) / k
                        let c = CGFloat(gx) + matrix.x0 * a + matrix.x1 * b
                        let d = CGFloat(gy) + matrix.y0 * a + matrix.y1 * b
                        let offsetIn = bytesPerRow * Int(cellSize.height * d) + 4 * Int(cellSize.width * c)
                        bytesOut[offset] = bytesIn[offsetIn]
                        bytesOut[offset+1] = bytesIn[offsetIn+1]
                        bytesOut[offset+2] = bytesIn[offsetIn+2]
                        bytesOut[offset+3] = bytesIn[offsetIn+3]
                    }
                    offset += 4
                }
            }
        }
        process(p1:ptE, p2:ptS, matrix:Matrix4(x0: 1,x1: 0,y0: 0,y1: 1))
        process(p1:ptS, p2:ptW, matrix:Matrix4(x0: 0,x1: -1,y0: 1,y1: 0))
        process(p1:ptW, p2:ptN, matrix:Matrix4(x0: -1,x1: 0,y0: 0,y1: -1))
        process(p1:ptN, p2:ptE, matrix:Matrix4(x0: 0,x1: 1,y0: -1,y1: 0))

        updateImage()
    }
    
    mutating func updateGrid2(x gx:Int, y gy:Int) {
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
