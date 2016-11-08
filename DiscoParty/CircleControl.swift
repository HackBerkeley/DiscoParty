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
fileprivate let buckets = 12

fileprivate class RainbowRingView: UIView {
    fileprivate override func draw(_ rect: CGRect) {
        let bounds = layer.bounds.squareInside()
        let center = bounds.center
        let ctx = UIGraphicsGetCurrentContext()!
        
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
}

fileprivate class BucketsView: UIView {
    fileprivate override func draw(_ rect: CGRect) {
        let bounds = layer.bounds.squareInside()
        let center = bounds.center
        let ctx = UIGraphicsGetCurrentContext()!
        
        let outerRadius = bounds.width / 2
        let innerRadius = (outerRadius * 2/3) + 1
        
        //this is the radius that the bucket centers will track around
        //it is between inner and outer radii
        let bucketCenterRadius = (innerRadius + outerRadius) / 2
        let bucketDiameter = outerRadius - innerRadius
        
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
}

/*
 The ringset defines a pair of specturm rings or bucket rings.
 */
fileprivate class RingSet: NSObject {
    let view = UIView(frame: CGRect.zero)
    
    lazy var innerRing : UIView = self.viewType.init(frame: CGRect.zero)
    lazy var outerRing : UIView = self.viewType.init(frame: CGRect.zero)
    
    let viewType : UIView.Type
    
    init(viewType : UIView.Type) {
        
        self.viewType = viewType
        
        super.init()
        
        for ring in [innerRing, outerRing] {
            view.addSubview(ring)
            ring.backgroundColor = UIColor.clear
        }
    }
    
    private(set) var active = true
    
    
    //Activation scales to 1
    func activate(animate: Bool) {
        active = true
        UIView.animate(withDuration: animate ? animationDuration / 2 : 0) {
            self.view.transform = CGAffineTransform.identity
        }
    }
    
    //Deactivation scales to 2 while fading to black
    //Then re-fades in the center at 4/9
    func deactivate(animate: Bool) {
        active = false
        
        if !animate {
            view.transform = CGAffineTransform(scaleX: centerProportion, y: centerProportion)
            return
        }
        
        UIView.animate(withDuration: animationDuration / 2, animations: {
            self.view.alpha = 0
        }, completion: {done in
            self.deactivate(animate: false)
            UIView.animate(withDuration: animationDuration / 2) {
                self.deactivate(animate: false)
                self.view.alpha = 1
            }
        })
    }
    
    /*
     Call layout only once when the view is added to a superview.
    */
    func layout() {
        outerRing.frame = view.bounds
        innerRing.frame = view.bounds.centered(scale: 2/3)
    }
    
    //0..2pi
    var rotation : CGFloat = 0 {
        didSet {
            outerRing.transform = CGAffineTransform(rotationAngle: rotation)
        }
    }
    
    /*
     Snap rotation to the buckets animatedly, and return
    */
    func snapToBuckets(completion: ((Bool)->Void)?) {
        CATransaction.begin()
        
        //the animation is consistent speed, not duration
        //since the max difference is 2pi/buckets, that is our max distance
        let angleDifference = abs(self.angleToBucket)
        let moveProportion = angleDifference / (twoPi / CGFloat(buckets))
        let dur = CFTimeInterval(moveProportion) * (animationDuration / 2)
        
        self.rotation += self.angleToBucket
        
    }
    
    /*
     Return the angular distance to the closest bucket
    */
    var angleToBucket : CGFloat {
        let prog = rotation / twoPi //rotation normalized to 0..1
        let bucketBefore = Int(floor(prog * CGFloat(buckets)))
        let bucketAfter = Int(ceil(prog * CGFloat(buckets)))
        
        let angleBefore = (CGFloat(bucketBefore) / CGFloat(buckets)) * twoPi
        let angleAfter = (CGFloat(bucketAfter) / CGFloat(buckets)) * twoPi
        
        let leastAngle = rotation - angleBefore < angleAfter - rotation ? angleBefore : angleAfter
        
        return leastAngle - rotation
    }
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
    
    private func doBucketSnap() {
        spectrums.snapToBuckets(completion: nil)
        buckets.snapToBuckets {done in
            self.value = Float(self.buckets.rotation / twoPi)
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
        
        if mode == .Bucket {
            doBucketSnap()
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
    
    private let spectrums = RingSet(viewType: RainbowRingView.self)
    private let buckets = RingSet(viewType: BucketsView.self)
    
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
            addSubview(ringSet.view)
            ringSet.view.frame = square
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
    
    private var dynamics : UIDynamicItemBehavior?
    private lazy var animator : UIDynamicAnimator = {
        let result = UIDynamicAnimator(referenceView: self)
        return result
    }()
    
    @objc private func pan(sender: UIPanGestureRecognizer) {
        
        let center = bounds.center
        let location = sender.location(in: self)
        
        switch (sender.state) {
        case .began:
            //stop spinning
            
            if let dyn = dynamics {
                
            }
            
            //when the pan first begins, record the touch location so we have a frame of reference
            firstTouch = location
            firstRotation = rotation
        case .changed:
            //calculate the angle difference
            
            //normalize each vector to the center
            let (vec1, vec2) = (center - firstTouch, center - location)
            
            let angle = atan2(vec2.y, vec2.x) - atan2(vec1.y, vec1.x)
            
            let newRotation = equivalentAngle(firstRotation + angle)
            
            value = Float(newRotation / twoPi)
            
            sendActions(for: .valueChanged)
        case .ended:
            
            /*
                     ^
                     |
        |
                     |
            */
            
            let vel = sender.velocity(in: self)
            let radius = center - location
            let motionRadius = radius + vel
            
            let angle = atan2(motionRadius.y, motionRadius.x) - atan2(radius.y, radius.x)
            //keep spinning based on how fast we flicked
            for set in ringSets {
                dynamics.addAngularVelocity(angle, for: set.outerRing)
            }
            
            //if buckets, set the value
            if mode == .Bucket {
                //snap the buckets ring to buckets
                doBucketSnap()
            }
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
