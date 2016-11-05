//
//  ImageProcessor.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/4/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import Foundation
import CoreImage

/*
 Each instance of ImageProcessor is not thread safe, however the class as a whole is.
 Create one instance of ImageProcessor for each thread.
 */

class ImageProcessor {
    
    //This is the filter that's going to colorize images.
    let hueFilter = HueShiftFilter()
    //And one to rotate
    let rotateFilter : CIFilter = {
        let result = CIFilter(name: "CIAffineTransform")!
        //rotate the image 90 cw
        let transform = CGAffineTransform(rotationAngle: -CGFloat(M_PI_2))
        let wrapped = NSValue(cgAffineTransform: transform)
        result.setValue(wrapped, forKey: "inputTransform")
        
        return result
    }()
    //And another to crop
    let cropFilter = CIFilter(name: "CICrop")!
    
    func process(image: CIImage, shiftHueBy: Float) -> CIImage {
        
        rotateFilter.setValue(image, forKey: "inputImage")
        
        let rotated = rotateFilter.value(forKey: "outputImage") as! CIImage
        
        //crop the image to be square
        cropFilter.setValue(rotated, forKey: "inputImage")
        
        let cropRect = rotated.extent.insetBy(dx: max(0, (rotated.extent.width - rotated.extent.height)/2), dy: max(0, (rotated.extent.height - rotated.extent.width)/2))
        
        let vector = CIVector(cgRect: cropRect)
        
        cropFilter.setValue(vector, forKey: "inputRectangle")
        
        let cropped = cropFilter.value(forKey: "outputImage") as! CIImage
        
        //change the hue
        hueFilter.inputImage = cropped
        hueFilter.inputShift = shiftHueBy
        
        return hueFilter.outputImage!
    }
}

class HueShiftFilter : CIFilter {
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
