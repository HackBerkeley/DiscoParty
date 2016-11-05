//
//  ViewController.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/4/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import UIKit
import AVFoundation
import GLKit

/*
 Since our application is only one view, the ViewController class is the heart of our application.
 This ViewController unifies the camera and file storage models with the user/facing views.
 */

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    /*
     This is the top view where the image preview is shown.
    */
    @IBOutlet weak var pictureView: UIView!
    let glView = CIGLView(frame: CGRect(x: 0, y: 0, width: 128, height:128), context: EAGLContext(api: .openGLES2))
    
    /*
     The hue shift value. This is between 0 and 1
     Swift doesn't have atomic variables, so I've had to make my own.
    */
    
    private var _hueShift : Float = 0
    private let hueMutex = PThreadMutex()
    
    var hueShift : Float {
        get {
            return hueMutex.sync {
                return _hueShift
            }
        }
        
        set {
            hueMutex.sync {
                _hueShift = newValue
            }
        }
    }
    
    @IBAction func hueShiftChanged(_ sender: UISlider) {
        hueShift = sender.value
    }
    
    
    /*
     The session object mediates our interaction with the camera.
    */
    let session = AVCaptureSession()
    
    //This is the output we use to take final photos.
    let photoOutput = AVCapturePhotoOutput()
    //Here's the output we use to preview frames.
    let previewOutput = AVCaptureVideoDataOutput()
    //Process the preview images on this queue
    let previewDispatchQueue = DispatchQueue(label: "Preview Processing")
    let previewProcessor = ImageProcessor()
    let previewRenderingContext = CIContext(options: nil)
    
    /*
     Sets up the above session to capture stills.
     Pre-condition: Authorization granted to the camera.
    */
    private func configureCaptureSession() {
        //Get the back camera device from the phone, and throw an error if for some reason the phone doesn't have a camera.
        guard let backCamera = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) else {
            fatalError("Couldn't get the rear camera!")
        }
        
        //try! is sketchy because we ignore error handing, but I'm allowing it because demo app.
        //"Wrap" the device in an input object. This is just how Apple designed the API.
        let input = try! AVCaptureDeviceInput(device: backCamera)
        
        session.addInput(input)
        
        //delegate the output to this object
        previewOutput.setSampleBufferDelegate(self, queue: previewDispatchQueue)
        
        session.addOutput(photoOutput)
        session.addOutput(previewOutput)
        
        //Set the background color to black to indiciate that view capture is ready to go
        pictureView.backgroundColor = UIColor.black
        
        session.startRunning()
        
        hueShift = 0.5
    }
    
    /*
     Sets up the interface in the event that the user denies authorization.
    */
    private func configureCaptureAuthorizationDenied() {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Setup GL view as subview of picture view
        pictureView.addSubview(glView)
        let constraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[gl]|", options: [], metrics: nil, views: ["gl": glView]) + NSLayoutConstraint.constraints(withVisualFormat: "V:|[gl]|", options: [], metrics: nil, views: ["gl": glView])
        pictureView.translatesAutoresizingMaskIntoConstraints = false
        glView.translatesAutoresizingMaskIntoConstraints = false
        pictureView.addConstraints(constraints)
        
        //We need to ask the user's permission to record video if we don't already have it.
        let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        switch authStatus {
        
        //In the case that we haven't been rejected or denied, ask the user for permission to their camera.
        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) {authorized in
                if authorized {
                    //Configure only if they granted authorization.
                    self.configureCaptureSession()
                }
            }
        
        //If we already have permission, go ahead and configure.
        case .authorized:
            configureCaptureSession()
            
        //Otherwise set state for having been denied
        default:
            configureCaptureAuthorizationDenied()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var prefersStatusBarHidden: Bool {return true}

    /*
     Preview output callback. Here we get data buffers and then need to process and display them.
    */
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        //get the video buffer from the sample buffer, which contains (potentially) audio and video
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let gpuImage = CIImage(cvImageBuffer: imageBuffer)
        
        //colorize the image and dispatch to main
        let result = previewProcessor.process(image: gpuImage, shiftHueBy: hueShift)
                
        //dispatch result to main
        DispatchQueue.main.async {
            self.glView.image = result
            self.glView.setNeedsDisplay()
        }
    }

}

