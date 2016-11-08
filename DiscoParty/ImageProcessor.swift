//
//  ImageProcessor.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/4/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import Foundation
import CoreImage

extension CGRect {
    /*
     Gets the square inscribed in the rect.
    */
    func squareInside() -> CGRect {
        return insetBy(dx: max(0, (width - height)/2), dy: max(0, (height - width)/2))
    }
}

/*
 Each instance of ImageProcessor is not thread safe, however the class as a whole is.
 Create one instance of ImageProcessor for each thread.
 */

class ImageProcessor {
    
    //This is the filter that's going to colorize images.
    private let hueFilter = HueShiftFilter()
    
    //And one to rotate/scale to the target size
    private let transformFilter = CIFilter(name: "CIAffineTransform")!

    private func set(transform: CGAffineTransform) {
        let wrapped = NSValue(cgAffineTransform: transform)
        transformFilter.setValue(wrapped, forKey: "inputTransform")
    }
    
    //And another to crop
    private let cropFilter = CIFilter(name: "CICrop")!
    
    /*
     Process the image. Hue shift is 0...1, target side length is the size of the final square image.
    */
    func process(image: CIImage, shiftHueBy: Float, targetSideLength: Int? = nil) -> CIImage {
        
        transformFilter.setValue(image, forKey: "inputImage")
        
        let rotateTransform = CGAffineTransform(rotationAngle: -CGFloat(M_PI_2))
        
        if let target = targetSideLength {
            //set transform with rotation and scale
            //the final side is going to be min(width, height)
            let scale = CGFloat(target) / min(image.extent.width, image.extent.height)
            
            set(transform: rotateTransform.scaledBy(x: scale, y: scale))
        } else {
            //otherwise just rotate
            set(transform: rotateTransform)
        }
        
        let rotated = transformFilter.value(forKey: "outputImage") as! CIImage
        
        //crop the image to be square
        cropFilter.setValue(rotated, forKey: "inputImage")
        
        let cropRect = rotated.extent.squareInside()
        
        let vector = CIVector(cgRect: cropRect)
        
        cropFilter.setValue(vector, forKey: "inputRectangle")
        
        let cropped = cropFilter.value(forKey: "outputImage") as! CIImage
        
        //change the hue
        hueFilter.inputImage = cropped
        hueFilter.inputShift = shiftHueBy
        
        return hueFilter.outputImage!
    }
}

fileprivate class HueShiftFilter : CIFilter {
    var inputImage : CIImage?
    var inputShift : Float = 0
    
    private static var kernel : CIColorKernel = {
        //Load the hue transformer shader that we created. Again `try!` because demo
        let programString = try! String(contentsOf: Bundle.main.url(forResource: "HueTransformer", withExtension: "shader")!)
        //create the actual processing kernel. again `!` because demo
        return CIColorKernel(string: programString)!
    }()
    
    override var outputImage : CIImage? {
        
        //if we're given a null image just return one too
        guard let input = inputImage else {return nil}
        
        let sampler = CISampler(image: input)
        
        return HueShiftFilter.kernel.apply(withExtent: input.extent, arguments: [sampler, inputShift])
    }
}
