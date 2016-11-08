//
//  GeometryUtils.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/8/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import UIKit

let twoPi = CGFloat(M_PI * 2)

extension CGRect {
    
    var isSquare : Bool {
        return abs(width - height) < 0.1
    }
    
    var center : CGPoint {return CGPoint(x: midX, y: midY)}
    
    /*
     Scales the rect by some value, keeping the center in the same place.
     The rect must be a square.
     */
    func centered(scale s: CGFloat) -> CGRect {
        assert(isSquare)
        let r = width / 2
        let shift = (r * (1 - s))
        return CGRect(x: origin.x + shift, y: origin.y + shift, width: width * s, height: height * s)
    }
    
    /*
     Adjust the square's size to some number of pixels, keeping the center the same.
     */
    
    func centered(side: CGFloat) -> CGRect {
        assert(isSquare)
        return centered(scale: side / width)
    }
    
    /*
     Adjusts the square's size by some number of pixels.
     */
    
    func centered(delta: CGFloat) -> CGRect {
        assert(isSquare)
        return centered(side: width + delta)
    }
    
    init(centered: CGPoint, size: CGSize) {
        origin = CGPoint(x: centered.x - (size.width / 2), y: centered.y - (size.height / 2))
        self.size = size
    }
    
}

/*
 These operator overloads let us add and subtract CGPoints as vectors.
 */

func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

func /(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
    return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
}

/*
 This is a custom dot product operator.
 */

infix operator •: MultiplicationPrecedence

func •(lhs: CGPoint, rhs: CGPoint) -> CGFloat {
    return (lhs.x * rhs.x) + (lhs.y * rhs.y)
}

extension CGPoint {
    var magnitude : CGFloat {
        return sqrt(self • self)
    }
    
    func normalized() -> CGPoint {
        return self / magnitude
    }
}
