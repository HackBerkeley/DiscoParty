//
//  CircleControl.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/7/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import UIKit

extension CGRect {
    
    var isSquare : Bool {
        return width == height
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
}

func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

class RingDrawer: NSObject, CALayerDelegate {
    func draw(_ layer: CALayer, in ctx: CGContext) {
        let bounds = layer.bounds
        let center = bounds.center
        let twoPi : CGFloat = 2 * CGFloat(M_PI)
        let r = bounds.width / 2
        
        //draw the rainbow by drawing colored lines from the center to the edge of the circle
        let inc : CGFloat = 0.005 //angle increment in radians
        
        var angle : CGFloat = 0
        
        ctx.setLineWidth(1)
        
        while angle < twoPi {
            
            let hue : CGFloat = angle / twoPi //hue is our progress through the circle
            
            let color = UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
            
            let radialPoint = center + CGPoint(x: r * cos(angle), y: r * sin(angle))
            
            ctx.setStrokeColor(color.cgColor)
            ctx.strokeLineSegments(between: [center, radialPoint])
            
            angle += inc
        }
        
        //draw the outer white circle in the bounds
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: bounds.insetBy(dx: 1, dy: 1))
    }
    
    static let shared = RingDrawer()
}

private func generateRingLayer() -> CALayer {
    let layer = CALayer()
    layer.delegate = RingDrawer.shared
    layer.needsDisplayOnBoundsChange = true
    return layer
}

/*
 This is the colored hue shift circle controller.
 
 This control is made up of two layers, which the user rotates.
 */

class CircleControl: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    

    
    let (innerRing, outerRing, centerRing) = (generateRingLayer(), generateRingLayer(), generateRingLayer())
    
    override func awakeFromNib() {
        super.awakeFromNib()
        commonInitializer()
    }
    
    private func commonInitializer() {
        for sub in [outerRing, innerRing, centerRing] {
            layer.addSublayer(sub)
        }
        
        layer.needsDisplayOnBoundsChange = true
        layer.delegate = self
        
        layer.setNeedsLayout()
    }
    
    override func layoutSublayers(of layer: CALayer) {        
        if layer == self.layer {
            //letterbox is the square region in the middle
            let squareBox = layer.bounds.squareInside()
            outerRing.frame = squareBox
            innerRing.frame = squareBox.scaledCenter(scale: 0.66)
            centerRing.frame = squareBox.scaledCenter(scale: 0.33)
        }
    }

}
