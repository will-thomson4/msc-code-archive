//
//  ViewController.swift
//  Capture
//
//  Created by William Thomson on 03/07/2022.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, AVCaptureDepthDataOutputDelegate {
    
    //AV Capture variables
    let captureSession = AVCaptureSession()
    let sessionOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    var isRecording = false
    
    //UI - links to Storyboard UI
    @IBOutlet var mainView: UIView!
    
    //Depth Capture Variables
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private let depthSessionQueue = DispatchQueue(label: "depthSessionQueue")
    
    private let depthStream = DepthStream()
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    //Needed for AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
    }
    
    //Run before view is shown on screen
    override func viewWillAppear(_ animated: Bool) {
        
        //Setup device and check it exists
        if let device = AVCaptureDevice.default(.builtInTrueDepthCamera,
                                                for: .video, position: .front) {
                
            do {
                let videoInput = try AVCaptureDeviceInput(device: device )

                //Setup camera
                if captureSession.canAddInput(videoInput) {
                    captureSession.sessionPreset = AVCaptureSession.Preset.photo
                    captureSession.addInput(videoInput)

                    if captureSession.canAddOutput(sessionOutput) {
                        captureSession.addOutput(sessionOutput)

                        //Setup camera preview layer
                        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                        previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                        
                        //Format preview layer
                        mainView.layer.addSublayer(previewLayer)
                        previewLayer.position = CGPoint(x: self.mainView.frame.width / 2, y: self.mainView.frame.height / 2)
                        previewLayer.zPosition = -1
                        previewLayer.bounds = mainView.frame
                    }
                    
                    // Add depth output
                    guard captureSession.canAddOutput(depthDataOutput) else { fatalError() }
                    captureSession.addOutput(depthDataOutput)
                    
                    depthDataOutput.isFilteringEnabled = false
                    
                    if let connection = depthDataOutput.connection(with: .depthData) {
                        connection.isEnabled = true
                        depthDataOutput.isFilteringEnabled = false
                        depthDataOutput.setDelegate(self, callbackQueue: depthSessionQueue)
                    } else {
                        print("No AVCaptureConnection")
                    }
                    
                    depthStream.configureSession()
                    
                    captureSession.addOutput(movieOutput)
                    captureSession.startRunning()
                }
                
                
            } catch {
                print("Error with video capture setup")
            }
        }
    }
    
    func startRecording(){
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("output.mov")
        movieOutput.startRecording(to: fileUrl, recordingDelegate: self)
        self.isRecording = true
    }
    
    func stopRecording() -> Void{
        movieOutput.stopRecording()
        self.isRecording = false
        do {
            try depthStream.finishRecording(success: { (url: URL) -> Void in
                print(url.absoluteString)
            })
        } catch {
            print("Error while finishing depth capture.")
        }
    }
    
    @IBAction func startPressed(_ sender: Any) {
        startRecording()
    }
    
    @IBAction func stopPressed(_ sender: Any) {
        stopRecording()
    }
    
    // Credit for this function goes to mantoone for his work on depth streaming
    // see https://github.com/mantoone/DepthCapture
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // Write depth data to a file
        if(self.isRecording) {
            let depthDataMap = depthData.depthDataMap
            //Add depth map to pixel buffer
            depthStream.addPixelBuffers(pixelBuffer: depthDataMap, callback: stopRecording)
        }
    }

}

