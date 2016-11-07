//
//  ViewController.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/4/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import UIKit
import AVFoundation
#if IOS_SIMULATOR
    import GLKit
#else
    import MetalKit
#endif

/*
 Utility function to get camera inputs.
 */

fileprivate func generateCameraInput(position: AVCaptureDevicePosition) -> AVCaptureDeviceInput {
    //Get the camera at position
    let camera = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: position)!
    
    //try! is sketchy because we ignore error handing, but I'm allowing it because demo app.
    //"Wrap" the device in an input object. This is just how Apple designed the API.
    let input = try! AVCaptureDeviceInput(device: camera)
    
    return input
}

/*
 Since our application is only one view, the ViewController class is the heart of our application.
 This ViewController unifies the camera and file storage models with the user/facing views.
 */

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {

    /*
     This is the top view where the image preview is shown.
    */
    @IBOutlet weak var pictureView: UIView!
    
    private var pictureViewRenderView : UIView? {
        #if IOS_SIMULATOR
            return glView
        #else
            return metalView
        #endif
    }
    
    /*
     The controls view contains our tirgger button and color selector.
    */
    
    @IBOutlet weak var controlsView: UIView!
    
    #if IOS_SIMULATOR
    /*
        Set up GL utils for drawing
    */
    let (glView, renderingContext, colorSpace) : (GLKView, CIContext, CGColorSpace) = {
        
        let glContext = EAGLContext(api: .openGLES2)!
        
        let view = GLKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), context: glContext)
        view.enableSetNeedsDisplay = false
        
        let context = CIContext(eaglContext: glContext)
        
        return (view, context, CGColorSpaceCreateDeviceRGB())
    }()
    #else
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
    #endif
    
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
    
    //Process the preview images on this queue
    let previewDispatchQueue = DispatchQueue(label: "Preview Processing")
    let previewProcessor = ImageProcessor()
    
    //We're also going to set up a seperate queue and processor for actually capturing images
    let captureQueue = DispatchQueue(label: "Capture Processing")
    let captureProcessor = ImageProcessor()
    
    //There is no camera on the simulator, and therefore no need to set up any capture.
    #if !IOS_SIMULATOR
    
    /*
     The session object mediates our interaction with the camera.
     The inputs are the various camera inputs we can add to it
    */
    private var session : AVCaptureSession!

    private let backCameraInput = generateCameraInput(position: .back)
    private let frontCameraInput = generateCameraInput(position: .front)
    
    private var currentCameraInput : AVCaptureDeviceInput?
    
    private func setCamera(input: AVCaptureDeviceInput) {
        if let curr = currentCameraInput {
            session.removeInput(curr)
        }
        
        session.addInput(input)
        currentCameraInput = input
    }
    
    private func flipCamera() {
        if currentCameraInput == backCameraInput {
            setCamera(input: frontCameraInput)
        } else {
            setCamera(input: backCameraInput)
        }
    }
    
    //This is the output we use to take final photos.
    let photoOutput = AVCapturePhotoOutput()
    //Here's the output we use to preview frames.
    let previewOutput = AVCaptureVideoDataOutput()
    
    /*
     Sets up the above session to capture stills.
     Pre-condition: Authorization granted to the camera.
    */
    private func configureCaptureSession() {
        
        session = AVCaptureSession()
        
        setCamera(input: backCameraInput)
        
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
    
    #endif
    
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
        
        #if IOS_SIMULATOR
        //blast the image buffer into the preview at 30fps
        Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) {timer in
            self.captureOutput(nil, didOutputSampleBuffer: self.testBuffer, from: nil)
        }
        
        #else
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
        #endif
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var prefersStatusBarHidden: Bool {return true}
    
    @IBAction func flipCamera(_ sender: Any) {
        #if !IOS_SIMULATOR
            flipCamera()
        #endif
    }
    
    /*
     Preview output callback. Here we get data buffers and then need to process and display them.
     This method is called on the preview queue as specified. Since we set the Metal view to only update manually, we can also update the Metal view from this other thread.
    */
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        #if IOS_SIMULATOR
            let side = glView.drawableWidth
        #else
            //ensure there's something to draw to in our metal view, otherwise bail
            guard let drawable = metalView.currentDrawable else {return}
            
            let side = drawable.texture.width
        #endif
        
        //get the video buffer from the sample buffer, which contains (potentially) audio and video
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let gpuImage = CIImage(cvImageBuffer: imageBuffer)
        
        //colorize the image and dispatch to main
        let result = previewProcessor.process(image: gpuImage, shiftHueBy: hueShift, targetSideLength: side)
        
        #if IOS_SIMULATOR
            let drawInRect : CGRect = {
                var rect = glView.bounds
                rect.size.width *= glView.contentScaleFactor
                rect.size.height *= glView.contentScaleFactor
                return rect
            }()
            renderingContext.draw(result, in: drawInRect, from: result.extent)
        #else
            let commandBuffer = previewCommandQueue.makeCommandBuffer()
            renderingContext.render(result, to: drawable.texture, commandBuffer: commandBuffer, bounds: result.extent, colorSpace: colorSpace)
            
            commandBuffer.present(drawable)
            
            commandBuffer.commit()
            
            //draw the metal view
            self.metalView.draw()
        #endif
    }
    
    #if IOS_SIMULATOR
    let testBuffer : CMSampleBuffer = {
        let image = #imageLiteral(resourceName: "TestImage").cgImage!
        
        let options : [String : NSNumber] = [kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        
        var pixelBuffer : CVPixelBuffer? = nil
        _ = CVPixelBufferCreate(kCFAllocatorDefault, image.width, image.height, kCVPixelFormatType_32ARGB, options as CFDictionary, &pixelBuffer)
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        
        let pxData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo:CGBitmapInfo = [.byteOrder32Little, CGBitmapInfo(rawValue: ~CGBitmapInfo.alphaInfoMask.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)]
        let context = CGContext(data: pxData, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow:
            CVPixelBufferGetBytesPerRow(pixelBuffer!), space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, [])
        
        var photoBuffer : CMSampleBuffer? = nil
        var description : CMFormatDescription?
        
        let extensions : [String : NSNumber] = [kCMFormatDescriptionExtension_BytesPerRow as String : NSNumber(value: CVPixelBufferGetBytesPerRow(pixelBuffer!))]
        
        CMFormatDescriptionCreate(kCFAllocatorDefault, kCMMediaType_Video, .allZeros, extensions as CFDictionary, &description)
        
        var timingInfo = kCMTimingInfoInvalid
        
        let result = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixelBuffer!, description!, &timingInfo, &photoBuffer)
        
        return photoBuffer!
        
    }()
    #endif

    /*This action triggers taking a picture*/
    @IBAction func takePicture(_ sender: Any) {
        #if IOS_SIMULATOR
            //on the simulator, simulate taking a picture by passing the test image into the capture routine
            doShutterAnimation()
            write(buffer: testBuffer)
        #else
            let format = photoOutput.availablePhotoPixelFormatTypes[0]
            let settings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String : format])
            settings.isHighResolutionPhotoEnabled = true
            photoOutput.capturePhoto(with: settings, delegate: self)
        #endif
    }
    
    /*
     The OS lets us know it's done capturing the picture. We pass this feedback on to the user in the form of a flash and a camera sound.
     */
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        doShutterAnimation()
    }
    
    private func doShutterAnimation() {
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
        
        write(buffer: photoSampleBuffer!)
    }
    
    private func write(buffer: CMSampleBuffer) {
        /*
         Spin the capture process out to a different queue. There's no reason you couldn't do this on the main thead, but it might cause lag since final captured images are generally fairly large.
         */
        captureQueue.async {
            let imageBuffer = CMSampleBufferGetImageBuffer(buffer)!
            let gpuImage = CIImage(cvImageBuffer: imageBuffer)
            
            let result = self.captureProcessor.process(image: gpuImage, shiftHueBy: self.hueShift)
            
            let rendered = self.renderingContext.createCGImage(result, from: result.extent)!
            
            let image = UIImage(cgImage: rendered)
            
            //render out the result with metal
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}

