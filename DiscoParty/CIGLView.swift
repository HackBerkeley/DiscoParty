//
//  CIGLView.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/5/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import UIKit
import CoreImage
import GLKit


//http://seanhenry.codes/ios/quick-and-easy-way-to-render-a-ciimage-on-the-gpu-using-glkit/

class CIGLView: GLKView {
    
    var image: CIImage?
    lazy var ciContext: CIContext = CIContext(eaglContext: self.context)
    
    override func draw(_ rect: CGRect) {
        if let image = self.image {
            // OpenGLES draws in pixels, not points so we scale to whatever the contents scale is.
            let scale = CGAffineTransform(scaleX: self.contentScaleFactor, y: self.contentScaleFactor)
            let drawingRect = rect.applying(scale)
            // The image.extent() is the bounds of the image.
            ciContext.draw(image, in: drawingRect, from: image.extent)
        }
    }
    
}
