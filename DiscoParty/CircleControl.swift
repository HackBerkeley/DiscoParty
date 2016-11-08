//
//  CircleControl.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/7/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import UIKit

fileprivate let centerProportion : CGFloat = 4/9
fileprivate let animationDuration : CFTimeInterval = 0.5

fileprivate class RingSet: NSObject, CALayerDelegate {
    let layer = CALayer()
    
    func generateRingLayer() -> CALayer {
        let layer = CALayer()
        layer.delegate = drawer
        layer.needsDisplayOnBoundsChange = true
        layer.contentsScale = UIScreen.main.scale //give the layer enough pixes for the retina screen
        return layer
    }
    
    let outerRingContainer = CALayer()
    
    lazy var innerRing : CALayer = self.generateRingLayer()
    lazy var outerRing : CALayer = self.generateRingLayer()
    
    let drawer : CALayerDelegate
    
    init(drawer : CALayerDelegate) {
        
        self.drawer = drawer
        
        super.init()
        
        layer.addSublayer(outerRingContainer)
        layer.addSublayer(innerRing)
        
        outerRingContainer.addSublayer(outerRing)
    }
    
    private(set) var active = true
    
    
    //Activation scales to 1
    func activate(animate: Bool) {
        active = true
        CATransaction.begin()
        CATransaction.setAnimationDuration(animate ? animationDuration / 2 : 0)
        layer.transform = CATransform3DMakeScale(1, 1, 1)
        CATransaction.commit()
    }
    
    //Deactivation scales to 2 while fading to black
    //Then re-fades in the center at 4/9
    func deactivate(animate: Bool) {
        active = false
        
        if !animate {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            layer.transform = CATransform3DMakeScale(centerProportion, centerProportion, 1)
            CATransaction.commit()
            return
        }
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(animationDuration / 2)
        
        CATransaction.setCompletionBlock {
            self.deactivate(animate: false)
            
            CATransaction.begin()
            CATransaction.setAnimationDuration(animationDuration / 2)
            
            self.layer.opacity = 1
            
            CATransaction.commit()
        }
        
        layer.opacity = 0
        
        CATransaction.commit()
    }
    
    /*
     Call layout only once when the layer is added to a superlayer.
    */
    func layout() {
        outerRingContainer.frame = layer.bounds
        outerRing.frame = outerRingContainer.bounds
        innerRing.frame = layer.bounds.centered(scale: 2/3)
    }
    
    //0..2pi
    var rotation : CGFloat = 0 {
        didSet {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            outerRingContainer.transform = CATransform3DMakeRotation(rotation, 0, 0, 1)
            CATransaction.commit()
        }
    }
}

fileprivate class RainbowRingDrawer: NSObject, CALayerDelegate {
    func draw(_ layer: CALayer, in ctx: CGContext) {
        let bounds = layer.bounds.squareInside()
        let center = bounds.center
        
        let outerRadius = bounds.width / 2
        let innerRadius = (outerRadius * 2/3) + 1
        
        //draw the rainbow by drawing colored lines from the center to the edge of the circle
        let inc : CGFloat = 0.005 //angle increment in radians
        
        var angle : CGFloat = 0
        
        ctx.setLineWidth(1)
        
        while angle < twoPi {
            
            //hue is our progress through the circle
            //add 0.25 so that red is at the top
            let hue : CGFloat = (angle / twoPi) + 0.25
            
            let color = UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
            
            let outerPoint = center + CGPoint(x: outerRadius * cos(angle), y: outerRadius * sin(angle))
            let innerPoint  = center + CGPoint(x: innerRadius * cos(angle), y: innerRadius * sin(angle))
            
            ctx.setStrokeColor(color.cgColor)
            ctx.strokeLineSegments(between: [innerPoint, outerPoint])
            
            angle += inc
        }
    }
    
    static let shared = RainbowRingDrawer()
}

fileprivate class BucketDrawer: NSObject, CALayerDelegate {
    func draw(_ layer: CALayer, in ctx: CGContext) {
        let bounds = layer.bounds.squareInside()
        let center = bounds.center
        
        let outerRadius = bounds.width / 2
        let innerRadius = (outerRadius * 2/3) + 1
        
        //this is the radius that the bucket centers will track around
        //it is between inner and outer radii
        let bucketCenterRadius = (innerRadius + outerRadius) / 2
        let bucketDiameter = outerRadius - innerRadius
        
        //Draw 10 buckets
        let buckets = 12
        
        for i in 0..<buckets {
            
            let prog = CGFloat(i) / CGFloat(buckets)
            
            let hue = prog + 0.25 //so red is a the top
            let angle = prog * twoPi
            
            let bucketCenter = center + CGPoint(x: bucketCenterRadius * cos(angle), y: bucketCenterRadius * sin(angle))
            let bucket = CGRect(centered: bucketCenter, size: CGSize(width: bucketDiameter, height: bucketDiameter))
            
            let color = UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
            ctx.setFillColor(color.cgColor)
            
            ctx.fillEllipse(in: bucket)
        }
    }
    
    static let shared = BucketDrawer()
}

/*
 This is the colored hue shift circle controller.
 
 This control is made up of two layers, which the user rotates.
 */

class CircleControl: UIControl, UIGestureRecognizerDelegate {

    //In radians
    var rotation : CGFloat {
        return CGFloat(value) * twoPi
    }
    
    var value : Float = 0 {
        didSet {
            for ringSet in ringSets {
                ringSet.rotation = rotation
            }
        }
    }
    
    enum Mode {
        case Spectrum
        case Bucket
    }
    
    private(set) var mode : Mode = .Spectrum
    
    func set(mode: Mode, animated: Bool) {
        self.mode = mode
        for ringSet in ringSets {
            if ringSet == activeRingSet {
                ringSet.activate(animate: animated)
            } else {
                ringSet.deactivate(animate: animated)
            }
        }
    }
    
    private var lastModeSwitch : CFTimeInterval?
    
    func switchMode(animated: Bool) {
        
        if let switchTime = lastModeSwitch, CACurrentMediaTime() - switchTime < animationDuration {
            return
        }
        
        lastModeSwitch = CACurrentMediaTime()
        
        if mode == .Bucket {
            set(mode: .Spectrum, animated: animated)
        } else {
            set(mode: .Bucket, animated: animated)
        }
    }
    
    private var activeRingSet : RingSet {
        switch mode {
        case .Spectrum:
            return spectrums
        case .Bucket:
            return buckets
        }
    }
    
    private let spectrums = RingSet(drawer: RainbowRingDrawer.shared)
    private let buckets = RingSet(drawer: BucketDrawer.shared)
    
    private var ringSets : [RingSet] {
        return [spectrums, buckets]
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        commonInitializer()
    }
    
    let panRecognizer = UIPanGestureRecognizer()
    let tapRecognizer = UITapGestureRecognizer()
    
    private func commonInitializer() {
        
        let square = layer.bounds.squareInside()
        
        for ringSet in ringSets {
            layer.addSublayer(ringSet.layer)
            ringSet.layer.frame = square
            ringSet.layout()
            
            if ringSet != activeRingSet {
                ringSet.deactivate(animate: false) //ringsets are active by default
            }
        }
        
        //add a gesture recognizer to recognize the circular gesture
        panRecognizer.addTarget(self, action: #selector(pan))
        panRecognizer.delegate = self //we're going to only let the recognizer work on the outer ring via shouldRecieveTouch
        addGestureRecognizer(panRecognizer)
        
        //add a gesture recognize to respond to a center tap to switch rings
        tapRecognizer.addTarget(self, action: #selector(tapCenter))
        tapRecognizer.delegate = self
        addGestureRecognizer(tapRecognizer)
    }
    
    /*
     We don't want to pan if the user's finger isn't on the outer ring.
     We know the outer ring is from 2/3 to the edge, so we can test if the touch is in the right by calculating its radius.
    */
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: self)
        let square = bounds.squareInside()
        let center = square.center
        
        //get a distance from touch to center
        let radius = (center - location).magnitude
        
        let outerRingRadius = square.width / 2
        
        let ratio = radius / outerRingRadius
        
        switch gestureRecognizer {
        case panRecognizer:
            return ratio > 0.25 && ratio < 1.1 //we'll give it an additional .1 for fat fingers
        case tapRecognizer:
            return ratio < centerProportion
        default:
            fatalError() //If a gesture recognizer isn't explicitly handled, throw an error
        }
    }
    
    private var firstTouch      : CGPoint!
    private var firstRotation   : CGFloat!
    
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
    
    @objc private func tapCenter(sender: UITapGestureRecognizer) {
        //we only care when the tap is done, so state completed
        if sender.state == .recognized {
            //switch the mode
            switchMode(animated: true)
        }
    }

}
