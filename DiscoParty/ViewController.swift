//
//  ViewController.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/4/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import UIKit
import AVFoundation

/*
 Since our application is only one view, the ViewController class is the heart of our application.
 This ViewController unifies the camera and file storage models with the user/facing views.
 */

class ViewController: UIViewController {

    /*
     This is the top view where the image preview is shown.
    */
    @IBOutlet weak var pictureView: UIView!
    
    /*
     The session object mediates our interaction with the camera.
    */
    let session = AVCaptureSession()
    
    //This is the output we use to take final photos.
    let photoOutput = AVCapturePhotoOutput()
    //Here's the output we use to preview frames.
    let previewOutput = AVCaptureVideoDataOutputSampleBufferDelegate()
    
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
        
        session.addOutput(photoOutput)
        
        //Set the background color to black to indiciate that view capture is ready to go
        pictureView.backgroundColor = UIColor.black
    }
    
    /*
     Sets up the interface in the event that the user denies authorization.
    */
    private func configureCaptureAuthorizationDenied() {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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


}

