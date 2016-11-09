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
    
    /*
value         1 0->
rotation    2pi 0->
             _____
            /     \
           |       |
0.75 3pi/2 |       | pi/2, 0.25
           |       |
            \_____/
     
              pi
              0.5
    */

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
        
        //This function generates the view
        func generateRing() -> UIImageView {
            let result = UIImageView(image: image)
            result.backgroundColor = UIColor.clear
            return result
        }
        
        //We return 2 generated views, one is the outer ring, one is the inner ring
        return (generateRing(), generateRing())
    }()
    
    /*
     The system calls this when it loads our view.
    */
    override func awakeFromNib() {
        super.awakeFromNib()
        
        /*
            Get the letterboxed square where we're going to place our view.
            
            square
                |
                V
             _ ____ _
            | |    | |
            | |    | |
            |_|____|_| <-bounds
        */
        let square = layer.bounds.squareInside()
        
        //Add the rings into our view
        addSubview(outerRing)
        addSubview(innerRing)
        
        //The outer ring sits in the square
        outerRing.frame = square
        //The inner ring sits at 2/3 the size
        innerRing.frame = square.centered(scale: 2/3)
        
        //add a gesture recognizer to recognize the circular gesture
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(pan))
        addGestureRecognizer(panRecognizer)
    }
    
    /*
     The pan works by calculating an angle delta from the initial touch.
     
     Hen
    */
    
    private var firstTouch      : CGPoint!
    private var firstRotation   : CGFloat!
    
    @objc private func pan(sender: UIPanGestureRecognizer) {
        /*
         The gesture recognizer (== panRecognizer above) has many different states.
         The two we care about are the 'began' state and the 'changed' state.
        */
        switch (sender.state) {
        case .began:
            //when the pan first begins, record the touch location so we have a frame of reference
            firstTouch = sender.location(in: self)
            //also record the rotation so we can add or subtract to it based on how the finger moves
            firstRotation = rotation
        case .changed:
            let location = sender.location(in: self)
            let center = bounds.center
            
            /*
                     firstTouch
              ______*_______
             |      ^       |
             |  vec1|_ angle|
             |      | |     |
             |center*------>* location
             |        vec2  |
             |              |
             |______________|
             
             It can be any angle, not just 90º
            */
            
            let (vec1, vec2) = (center - firstTouch, center - location)
            
            let angle = atan2(vec2.y, vec2.x) - atan2(vec1.y, vec1.x)
            
            /*
             Our new rotation is the rotation where we first touched plus how much we dragged.
             equivalentAngle keeps the angle between 0..2pi
            */
            let newRotation = equivalentAngle(firstRotation + angle)
            
            /*
             Since the max newRotation is 2pi, we can set value based on it.
            */
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
