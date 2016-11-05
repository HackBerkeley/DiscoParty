//
//  Colorist.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/4/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import Foundation
import CoreImage

/*
 Each instance of Colorist is not thread safe, however the class as a whole is.
 Create one instance of Colorist for each thread.
 */

class Colorist {
    
    //This is the filter that's going to colorize images.
    let filter = HueShiftFilter()
    
    func colorize(image: CIImage, shiftHueBy: CGFloat) -> CIImage {
        filter.inputImage = image
        filter.inputShift = shiftHueBy
        
        return filter.outputImage!
    }
}

class HueShiftFilter : CIFilter {
    var inputImage : CIImage?
    var inputShift : CGFloat = 0
    
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
