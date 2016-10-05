//
//  SNMorphGrid.swift
//  SNMorph
//
//  Created by satoshi on 10/2/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

private extension UIImage {
    func imageWith(limit:CGFloat) -> UIImage {
        let size = self.size
        let scale = min(limit / size.width, limit / size.height, 1)
        return { Void -> UIImage in
            let frame = CGRect(x:0, y:0, width: size.width * scale, height: size.height * scale)
            UIGraphicsBeginImageContext(frame.size)
            defer { UIGraphicsEndImageContext() }
            self.draw(in: frame)
            return UIGraphicsGetImageFromCurrentImageContext()!
        } ()
    }
}

struct SNMorphGrid {
    var cgImage:CGImage?
    let slice:(x:Int, y:Int)
    let border:Int
    let gridX:Int, gridY:Int
    let cellSize:CGSize
    let size:CGSize
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
    init(image:UIImage, slice:(x:Int, y:Int), border:Int, limit:CGFloat) {
        let imageResized = image.imageWith(limit: limit)
        self.slice = slice
        self.border = border
        gridX = slice.x + border * 2
        gridY = slice.y + border * 2
        cellSize = CGSize(width: imageResized.size.width / CGFloat(slice.x),
                          height: imageResized.size.height / CGFloat(slice.y))
        size = CGSize(width:cellSize.width * CGFloat(gridX),
                                height:cellSize.height * CGFloat(gridY))
        let length = 4 * Int(size.width) * Int(size.height)
        let data = NSMutableData(length: length)!
        let context = CGContext(data: data.mutableBytes, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        
        let origin = CGPoint(x:cellSize.width * CGFloat(border), y:cellSize.height * CGFloat(border))
        context.draw(imageResized.cgImage!, in: CGRect(origin: origin, size:imageResized.size))
        dataIn = data
        dataOut = NSMutableData(length: length)!
        memcpy(dataOut.mutableBytes, dataIn.bytes, length)
        
        dataMap = NSMutableData(length: MemoryLayout<CGPoint>.size * Int(size.width) * Int(size.height))!
        let bytesMap = UnsafeMutablePointer<CGPoint>(OpaquePointer(dataMap.mutableBytes))
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                bytesMap[y * Int(size.width) + x] = CGPoint(x: CGFloat(x) / cellSize.width, y:CGFloat(y) / cellSize.height)
            }
        }
        updateImage()
    }
    
    private mutating func updateImage() {
        let context = CGContext(data: dataOut.mutableBytes, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        cgImage = context.makeImage()
    }
    
    func map(pt:CGPoint) -> CGPoint {
        let bytesMap = UnsafeMutablePointer<CGPoint>(OpaquePointer(dataMap.mutableBytes))
        return bytesMap[Int(pt.y) * Int(size.width) + Int(pt.x)]
    }
    
    mutating func undateHandle(x:Int, y:Int, pt:CGPoint) {
        guard 0 < x && x < gridX && 0 < y && y < gridY else {
            return
        }
        handles[x][y] = pt
        updateGrid(x: x, y: y)
    }
    
    mutating func boundChecker(x:Int, y:Int) -> (CGPoint)->Bool {
        let ptW = handles[x-1][y]
        let ptN = handles[x][y-1]
        let ptNE = handles[x+1][y-1]
        let ptE = handles[x+1][y]
        let ptS = handles[x][y+1]
        let ptSE = handles[x-1][y+1]
        return { pt in
            return ptN.delta(from: ptW).crossProduct(with: pt.delta(from: ptW)) > 0
                && ptNE.delta(from: ptN).crossProduct(with: pt.delta(from: ptN)) > 0
                && ptE.delta(from: ptNE).crossProduct(with: pt.delta(from: ptNE)) > 0
                && ptS.delta(from: ptE).crossProduct(with: pt.delta(from: ptE)) > 0
                && ptSE.delta(from: ptS).crossProduct(with: pt.delta(from: ptS)) > 0
                && ptW.delta(from: ptSE).crossProduct(with: pt.delta(from: ptSE)) > 0
        }
    }

    mutating func updateGrid(x gx:Int, y gy:Int) {
        struct RGBAColor {
            var r:UInt8
            var g:UInt8
            var b:UInt8
            var a:UInt8
            var red:CGFloat { return CGFloat(r) }
            var green:CGFloat { return CGFloat(g) }
            var blue:CGFloat { return CGFloat(b) }
            var alpha:CGFloat { return CGFloat(a) }
        }
        let wordsPerRow = Int(size.width)
        let wordsOut = UnsafeMutablePointer<RGBAColor>(OpaquePointer(dataOut.mutableBytes))
        let wordsIn = UnsafePointer<RGBAColor>(OpaquePointer(dataIn.bytes))
        let bytesMap = UnsafeMutablePointer<CGPoint>(OpaquePointer(dataMap.mutableBytes))
        
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
                let offsetOut = wordsPerRow * (origin.y + y) + origin.x
                let offsetMap = Int(size.width) * (origin.y + y) + origin.x
                for x in 0..<(target.x - origin.x) {
                    let pt = CGPoint(x: CGFloat(origin.x + x), y: CGFloat(origin.y + y))
                    let d0 = pt.delta(from: p0)
                    if d10.crossProduct(with: d0) >= 0
                      && d21.crossProduct(with: pt.delta(from: p1)) >= 0
                      && d02.crossProduct(with: pt.delta(from: p2)) >= 0 {
                        let a = (d0.y * d20.x - d0.x * d20.y) / k
                        let b = (d0.x * d10.y - d0.y * d10.x) / k
                        let ptMap = CGPoint(x: CGFloat(gx) + CGFloat(dir) * a, y: CGFloat(gy) + CGFloat(dir) * b)
                        let ptTarget = CGPoint(x: cellSize.width * ptMap.x, y: cellSize.height * ptMap.y)
                        let ptGrid = CGPoint(x: floor(ptTarget.x), y: floor(ptTarget.y))
                        let offsetIn = wordsPerRow * Int(ptGrid.y) + Int(ptGrid.x)
                        var color = wordsIn[offsetIn]

                        let rx = ptTarget.x - ptGrid.x, ry = ptTarget.y - ptGrid.y
                        let c00 = wordsIn[offsetIn]
                        let w00 = (1 - rx) * (1 - ry)
                        let c01 = wordsIn[offsetIn + 1]
                        let w01 = rx * (1 - ry)
                        let c10 = wordsIn[offsetIn + wordsPerRow]
                        let w10 = (1 - rx) * ry
                        let c11 = wordsIn[offsetIn + wordsPerRow + 1]
                        let w11 = rx * ry
                        color.r = UInt8(c00.red * w00 + c01.red * w01 + c10.red * w10 + c11.red * w11)
                        color.g = UInt8(c00.green * w00 + c01.green * w01 + c10.green * w10 + c11.green * w11)
                        color.b = UInt8(c00.blue * w00 + c01.blue * w01 + c10.blue * w10 + c11.blue * w11)

                        wordsOut[offsetOut + x] = color
                        bytesMap[offsetMap + x] = ptMap
                    }
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
