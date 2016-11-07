//
//  SimulatorGLView.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/6/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import UIKit
import GLKit

class SimulatorGLView: GLKView {
    
    var image : CIImage?
    var computeContext : CIContext?
    
    func display(image: CIImage, context: CIContext) {
        self.image = image
        computeContext = context
        display()
    }
    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
        guard let image = image, let context = computeContext else {return}
        
        let drawInRect : CGRect = {
            var rect = bounds
            rect.size.width *= contentScaleFactor
            rect.size.height *= contentScaleFactor
            return rect
        }()
        context.draw(image, in: drawInRect, from: image.extent)
        self.image = nil
        computeContext = nil
    }
 

}
