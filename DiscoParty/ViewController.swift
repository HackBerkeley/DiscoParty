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
import MetalKit

/*
 Since our application is only one view, the ViewController class is the heart of our application.
 This ViewController unifies the camera and file storage models with the user/facing views.
 */

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {

    /*
     This is the top view where the image preview is shown.
    */
    @IBOutlet weak var pictureView: UIView!
    
    var pictureViewRenderView : UIView? {return metalView}
    
    /*
     The controls view contains our tirgger button and color selector.
    */
    
    @IBOutlet weak var controlsView: UIView!
    
    /*
     Setup metal utils for drawing
     We can use the same renderingContext in multiple threads because it's thread safe according to the documentaiton.
     */
    let (metalDevice, metalView, renderingContext, previewCommandQueue, colorSpace) : (MTLDevice, MTKView, CIContext, MTLCommandQueue, CGColorSpace) = {
        let device =  MTLCreateSystemDefaultDevice()!
        
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), device: device)
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        view.framebufferOnly = false
        
        let context = CIContext(mtlDevice: device)
        
        let queue = device.makeCommandQueue()
        
        return (device, view, context, queue, CGColorSpaceCreateDeviceRGB())
    }()
    
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
    var session : AVCaptureSession!
    
    //This is the output we use to take final photos.
    let photoOutput = AVCapturePhotoOutput()
    //Here's the output we use to preview frames.
    let previewOutput = AVCaptureVideoDataOutput()
    //Process the preview images on this queue
    let previewDispatchQueue = DispatchQueue(label: "Preview Processing")
    let previewProcessor = ImageProcessor()
    
    //We're also going to set up a seperate queue and processor for actually capturing images
    let captureQueue = DispatchQueue(label: "Capture Processing")
    let captureProcessor = ImageProcessor()
    
    /*
     Sets up the above session to capture stills.
     Pre-condition: Authorization granted to the camera.
    */
    private func configureCaptureSession() {
        
        session = AVCaptureSession()
        
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
        
        photoOutput.isHighResolutionCaptureEnabled = true
        session.addOutput(photoOutput)
        
        session.addOutput(previewOutput)
        
        //Set the background color to white to indiciate that view capture is ready to go
        //this will also let us fade out the metal view when we take a picture
        pictureView.backgroundColor = UIColor.white
        
        session.startRunning()
        
        hueShift = 0.5
    }
    
    /*
     Sets up the interface in the event that the user denies authorization.
    */
    private func configureCaptureAuthorizationDenied() {
        pictureView.backgroundColor = UIColor.red //set to red to indicate there's been an error
    }
    
    /*
     Setup the controls view the appropriate graphic stylings.
    */
    private func configureControlsView() {
        controlsView.backgroundColor = UIColor.black
        controlsView.tintColor = UIColor.white
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureControlsView()
        
        //Setup GL view as subview of picture view
        if let subview = pictureViewRenderView {
            pictureView.addSubview(subview)
            let constraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[gl]|", options: [], metrics: nil, views: ["gl": subview]) + NSLayoutConstraint.constraints(withVisualFormat: "V:|[gl]|", options: [], metrics: nil, views: ["gl": subview])
            subview.translatesAutoresizingMaskIntoConstraints = false
            pictureView.addConstraints(constraints)
        }
        
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
        
        //get notified when the app sleeps and stop the session
        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground, object: nil, queue: nil) {note in
            self.session.stopRunning()
        }
        
        NotificationCenter.default.addObserver(forName: .UIApplicationWillEnterForeground, object: nil, queue: nil) {note in
            self.configureCaptureSession()
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
        
        //ensure there's something to draw to in our metal view, otherwise bail
        guard let drawable = metalView.currentDrawable else {return}
        
        //get the video buffer from the sample buffer, which contains (potentially) audio and video
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let gpuImage = CIImage(cvImageBuffer: imageBuffer)
        
        //colorize the image and dispatch to main
        let result = previewProcessor.process(image: gpuImage, shiftHueBy: hueShift, targetSideLength: drawable.texture.width)
        
        let commandBuffer = previewCommandQueue.makeCommandBuffer()
        renderingContext.render(result, to: drawable.texture, commandBuffer: commandBuffer, bounds: result.extent, colorSpace: colorSpace)
        
        commandBuffer.present(drawable)
        
        commandBuffer.commit()
        
        //draw the metal view
        self.metalView.draw()
    }

    /*This action triggers taking a picture*/
    @IBAction func takePicture(_ sender: Any) {
        let format = photoOutput.availablePhotoPixelFormatTypes[0]
        let settings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String : format])
        settings.isHighResolutionPhotoEnabled = true
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    /*
     The OS lets us know it's done capturing the picture. We pass this feedback on to the user in the form of a flash and a camera sound.
     */
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        AudioServicesPlaySystemSound(1108)
        let totalDuration : CFTimeInterval = 0.25
        UIView.animate(withDuration: totalDuration / 2, animations: {
            self.pictureView.alpha = 0
        }, completion: {done in
            UIView.animate(withDuration: totalDuration / 2, animations: {
                self.pictureView.alpha = 1
            })
        })
    }
    
    /*
     When the hardware is done taking the picture, this function is called back to. Then we can process the image on another queue.
    */
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        captureQueue.async {
            let imageBuffer = CMSampleBufferGetImageBuffer(photoSampleBuffer!)!
            let gpuImage = CIImage(cvImageBuffer: imageBuffer)
            
            let result = self.captureProcessor.process(image: gpuImage, shiftHueBy: self.hueShift)
            
            let rendered = self.renderingContext.createCGImage(result, from: result.extent)!
            
            let image = UIImage(cgImage: rendered)
            
            //render out the result with metal
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}

