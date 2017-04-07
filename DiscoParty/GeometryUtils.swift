//
//  GeometryUtils.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/8/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import UIKit

let twoPi = CGFloat(Double.pi * 2)

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

/*
 Given an angle, returns an equivalent angle 0...2pi
 */
func equivalentAngle(_ angle: CGFloat) -> CGFloat {
    
    var result = angle
    
    while result < 0 {
        result += twoPi
    }
    
    while result > twoPi {
        result -= twoPi
    }
    
    return result
}
