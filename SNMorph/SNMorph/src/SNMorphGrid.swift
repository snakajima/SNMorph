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
    private let gridX:Int, gridY:Int
    private let gridSize:CGSize
    private let size:CGSize
    private let dataIn:NSData
    private let dataOut:NSMutableData
    private let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
    init(image:UIImage, slice:(x:Int, y:Int), border:Int) {
        self.slice = slice
        self.border = border
        gridX = slice.x + border * 2
        gridY = slice.y + border * 2
        gridSize = CGSize(width: image.size.width / CGFloat(slice.x),
                          height: image.size.width / CGFloat(slice.y))
        size = CGSize(width:gridSize.width * CGFloat(gridX),
                                height:gridSize.height * CGFloat(gridX))
        let length = 4 * Int(size.width) * Int(size.height)
        let data = NSMutableData(length: length)!
        let context = CGContext(data: data.mutableBytes, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        let origin = CGPoint(x:gridSize.width * CGFloat(border), y:gridSize.height * CGFloat(border))
        context.draw(image.cgImage!, in: CGRect(origin: origin, size:image.size))
        dataIn = data
        cgImage = context.makeImage() // test code

        dataOut = NSMutableData(length: length)!
        memcpy(dataOut.mutableBytes, dataIn.bytes, length)
        
        //updateImage()
    }
    
    private mutating func updateImage() {
        let context = CGContext(data: dataOut.mutableBytes, width: gridX, height: gridY, bitsPerComponent: 8, bytesPerRow: 4 * gridX, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        cgImage = context.makeImage()
    }
}
