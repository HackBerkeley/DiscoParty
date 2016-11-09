//
//  CircleControl.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/7/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import UIKit

/*
 This is the colored hue shift circle view.
 This control is made up of two layers, which the user rotates.
 */

class CircleControl: UIControl {

    //The rotation of the outer circle in radians. We can compute this from the value.
    var rotation : CGFloat {
        return CGFloat(value) * twoPi
    }
    
    //The value that our control represents 0...1
    var value : Float = 0 {
        didSet {
            outerRing.transform = CGAffineTransform(rotationAngle: rotation)
        }
    }
    
    /*
     Creates two image views with the color ring image.
    */
    let (outerRing, innerRing) : (UIImageView, UIImageView) = {
        let image = UIImage(named: "ring")!
        return (UIImageView(image: image), UIImageView(image: image))
    }()
    
    /*
     The system calls this when it loads our view.
    */
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let square = layer.bounds.squareInside()
        
        for view in [innerRing, outerRing] {
            addSubview(view)
            view.backgroundColor = UIColor.clear
        }
        
        outerRing.frame = square
        innerRing.frame = square.centered(scale: 2/3)
        
        //add a gesture recognizer to recognize the circular gesture
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(pan))
        addGestureRecognizer(panRecognizer)
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
            
            let newRotation = equivalentAngle(firstRotation + angle)
            
            value = Float(newRotation / twoPi)
            
            /*
             We inherit this function from our UIControl parent.
             Calling it does all the connected actions.
            */
            sendActions(for: .valueChanged)
        default:
            break
        }
    }
}
