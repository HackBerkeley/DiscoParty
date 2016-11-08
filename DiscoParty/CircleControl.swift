//
//  CircleControl.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/7/16.
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
    func scaledCenter(scale s: CGFloat) -> CGRect {
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
        return scaledCenter(scale: side / width)
    }
    
    /*
     Adjusts the square's size by some number of pixels.
    */
    
    func centered(delta: CGFloat) -> CGRect {
        assert(isSquare)
        return centered(side: width + delta)
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

class RainbowRingDrawer: NSObject, CALayerDelegate {
    func draw(_ layer: CALayer, in ctx: CGContext) {
        let bounds = layer.bounds.squareInside()
        let center = bounds.center
        let r = bounds.width / 2
        
        //draw the rainbow by drawing colored lines from the center to the edge of the circle
        let inc : CGFloat = 0.005 //angle increment in radians
        
        var angle : CGFloat = 0
        
        ctx.setLineWidth(1)
        
        while angle < twoPi {
            
            let hue : CGFloat = (angle / twoPi) + 0.25 //hue is our progress through the circle
            
            let color = UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
            
            let radialPoint = center + CGPoint(x: r * cos(angle), y: r * sin(angle))
            
            ctx.setStrokeColor(color.cgColor)
            ctx.strokeLineSegments(between: [center, radialPoint])
            
            angle += inc
        }
        
        //draw a black circle that fills up 2/3 of the ring plus one pixel
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fillEllipse(in: bounds.scaledCenter(scale: 2/3).centered(delta: 1))
    }
    
    static let shared = RainbowRingDrawer()
}

private func generateRainbowRingLayer() -> CALayer {
    let layer = CALayer()
    layer.delegate = RainbowRingDrawer.shared
    layer.needsDisplayOnBoundsChange = true
    layer.contentsScale = UIScreen.main.scale
    return layer
}

/*
 This is the colored hue shift circle controller.
 
 This control is made up of two layers, which the user rotates.
 */

class CircleControl: UIControl {

    //In radians
    var rotation : CGFloat {
        return CGFloat(value) * twoPi
    }
    
    var value : Float = 0 {
        didSet {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            outerRingContainer.transform = CATransform3DMakeRotation(rotation, 0, 0, 1)
            CATransaction.commit()
        }
    }
    
    let (innerRing, outerRing) = (generateRainbowRingLayer(), generateRainbowRingLayer())
    
    let outerRingContainer = CALayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        commonInitializer()
    }
    
    private func commonInitializer() {
        for sub in [outerRingContainer, innerRing] {
            layer.addSublayer(sub)
        }
        
        outerRingContainer.addSublayer(outerRing)
        
        //letterbox is the square region in the middle
        let squareBox = layer.bounds.squareInside()
        outerRingContainer.frame = squareBox
        outerRing.frame = outerRingContainer.bounds
        innerRing.frame = squareBox.scaledCenter(scale: 0.66)
        
        //add a gesture recognizer to recognize the circular gesture
        let gest = UIPanGestureRecognizer(target: self, action: #selector(pan))
        
        addGestureRecognizer(gest)
    }
    
    var firstTouch      : CGPoint!
    var firstRotation   : CGFloat!
    
    @objc private func pan(sender: UIPanGestureRecognizer) {
        switch (sender.state) {
        case .began:
            //when the pan first begins, record the touch location so we have a frame of reference
            firstTouch = sender.location(in: self)
            firstRotation = rotation
        case .changed:
            //calculate the angle difference
            let location = sender.location(in: self)
            let center = bounds.center
            
            //normalize each vector to the center
            let (vec1, vec2) = (center - firstTouch, center - location)
            
            let angle = atan2(vec2.y, vec2.x) - atan2(vec1.y, vec1.x)
            
            var newRotation = firstRotation + angle
            
            //keep the rotation in bounds
            
            while newRotation < 0 {
                newRotation += twoPi
            }
            
            while newRotation > twoPi {
                newRotation -= twoPi
            }
            
            value = Float(newRotation / twoPi)
            
            sendActions(for: .valueChanged)
        default:
            break
        }
    }

}
