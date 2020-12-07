//
//  ViewController.swift
//  CameraDemo
//
//  Created by Wei-Cheng Ling on 2020/12/3.
//

import Cocoa
import Vision
import AVFoundation


class ViewController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    enum FaceMask : String {
        case rectangle = "Rectangle"
        case emoji     = "Emoji"
    }
    
    enum DetectMode : String {
        case none   = "None"
        case face   = "Face"
        case object = "Object"
    }
    
    
    @IBOutlet var camerasPopUpButton : NSPopUpButton!
    @IBOutlet var detectModePopUpButton : NSPopUpButton!
    @IBOutlet var faceMasksPopUpButton : NSPopUpButton!
    @IBOutlet var videoMirrorSwitch : NSSwitch!
    @IBOutlet var videoMirrorLabel : NSTextField!
    
    
    var hasCameraDevice = false
    var cameraDevices : [AVCaptureDevice]!
    var currentCameraDevice : AVCaptureDevice!
    var previewLayer : AVCaptureVideoPreviewLayer!
    var videoSession : AVCaptureSession!
    
    let detectModes : Array<DetectMode> = [.none, .face, .object]
    var faceMasks = [FaceMask]()
    var faceViews = [NSView]()
    var detectMode = DetectMode.none
    var faceMask = FaceMask.rectangle
    
    var faceEmoji = "😊"
    let faceEmojiArray = ["😊", "☺️", "🥰", "😍", "😉", "😌", "😎",
                          "🥸", "😱", "🤫", "👺", "🤡", "🎃", "👽"]
    
    
    
    // MARK: - viewLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // hide videoMirrorComponents
        hideVideoMirrorComponents()
        
        // setup Camera
        cameraDevices = getCameraDevices()
        setupCamerasPopUpButton()
        setupDefaultCamera()
        
        // setup UI Components
        setupDetectModePopUpButton()
        setupFaceMasksPopUpButton()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    
    // MARK: - Setup
    
    func setupCamerasPopUpButton() {
        camerasPopUpButton.removeAllItems()
        
        if cameraDevices.count <= 0 {
            camerasPopUpButton.addItem(withTitle: "-- No Camera Device --")
            hasCameraDevice = false
            return
        }
        
        for device in cameraDevices {
            camerasPopUpButton.addItem(withTitle: "\(device.localizedName)")
        }
        hasCameraDevice = true
    }
    
    func setupDefaultCamera() {
        if cameraDevices.count > 0 {
            if let device = cameraDevices.first {
                startUpCameraDevice(device)
            }
        }
    }
    
    func setupDetectModePopUpButton() {
        detectModePopUpButton.removeAllItems()
        if !hasCameraDevice { return }
        
        for mode in detectModes {
            if mode == .none {
                detectModePopUpButton.addItem(withTitle: "No Detection")
            } else {
                detectModePopUpButton.addItem(withTitle: "\(mode.rawValue) Detection")
            }
        }
    }
    
    func setupFaceMasksPopUpButton() {
        faceMasksPopUpButton.removeAllItems()
        
        faceMasks.append(.rectangle)
        for _ in faceEmojiArray {
            faceMasks.append(.emoji)
        }
        
        var index = -1
        for mask in faceMasks {
            if index == -1 {
                // .rectangle
                faceMasksPopUpButton.addItem(withTitle: "\(mask.rawValue)")
            } else if index >= 0 {
                // .emoji
                if index < faceEmojiArray.count {
                    let emoji = faceEmojiArray[index]
                    faceMasksPopUpButton.addItem(withTitle: "\(mask.rawValue)  \(emoji) ")
                }
            }
            index += 1
        }
        faceMasksPopUpButton.isHidden = true
    }
    
    func hideVideoMirrorComponents() {
        videoMirrorSwitch.state = .off
        videoMirrorSwitch.isHidden = true
        videoMirrorLabel.isHidden = true
    }
    
    
    // MARK: - Camera Devices
    
    func getCameraDevices() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                                                                mediaType: .video,
                                                                position: .unspecified)
        return discoverySession.devices
    }
    
    func startUpCameraDevice(_ device: AVCaptureDevice) {
        if prepareCamera(device) {
            startSession()
        }
    }
        
    func prepareCamera(_ device: AVCaptureDevice) -> Bool {
        currentCameraDevice = device
        
        videoSession = AVCaptureSession()
        videoSession.sessionPreset = AVCaptureSession.Preset.vga640x480
        previewLayer = AVCaptureVideoPreviewLayer(session: videoSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if videoSession.canAddInput(input) {
                videoSession.addInput(input)
            }
            
            if let previewLayer = self.previewLayer {
                if let isVideoMirroringSupported = previewLayer.connection?.isVideoMirroringSupported,
                   isVideoMirroringSupported == true
                {
                    previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
                    previewLayer.connection?.isVideoMirrored = false
                    videoMirrorLabel.isHidden = false
                    videoMirrorLabel.textColor = NSColor.darkGray
                    videoMirrorSwitch.isHidden = false
                    videoMirrorSwitch.state = .off
                } else {
                    videoMirrorLabel.isHidden = true
                    videoMirrorSwitch.isHidden = true
                }
                previewLayer.frame = self.view.bounds
                view.layer = previewLayer
                view.wantsLayer = true
            }
        } catch {
            print(error.localizedDescription)
            return false
        }
            
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate", attributes: []))
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        
        if videoSession.canAddOutput(videoOutput) {
            videoSession.addOutput(videoOutput)
            
        }
        return true
    }
    
    
    // MARK: - Video Session
    
    func startSession() {
        if let videoSession = videoSession {
            if !videoSession.isRunning {
                videoSession.startRunning()
            }
        }
    }
        
    func stopSession() {
        if let videoSession = videoSession {
            if videoSession.isRunning {
                videoSession.stopRunning()
            }
        }
    }
    
    
    // MARK: - IBAction
    
    @IBAction func selectCamerasPopUpButton(_ sender: NSPopUpButton) {
        if !hasCameraDevice { return }
        print("\(sender.indexOfSelectedItem) : \(sender.titleOfSelectedItem ?? "")")
        
        if sender.indexOfSelectedItem < cameraDevices.count {
            let device = cameraDevices[sender.indexOfSelectedItem]
            startUpCameraDevice(device)
        }
    }
    
    @IBAction func selectDetectModePopUpButton(_ sender: NSPopUpButton) {
        print("\(sender.indexOfSelectedItem) : \(sender.titleOfSelectedItem ?? "")")
        
        if sender.indexOfSelectedItem < detectModes.count {
            detectMode = detectModes[sender.indexOfSelectedItem]
            
            if detectMode == .face {
                faceMasksPopUpButton.isHidden = false
            } else {
                faceMasksPopUpButton.isHidden = true
            }
        }
    }
    
    @IBAction func selectFaceMasksPopUpButton(_ sender: NSPopUpButton) {
        print("\(sender.indexOfSelectedItem) : \(sender.titleOfSelectedItem ?? "")")
        
        if sender.indexOfSelectedItem < faceMasks.count {
            faceMask = faceMasks[sender.indexOfSelectedItem]
            
            if faceMask == .emoji {
                let emojiIndex = sender.indexOfSelectedItem - 1
                if emojiIndex < faceEmojiArray.count {
                    faceEmoji = faceEmojiArray[emojiIndex]
                } else {
                    faceEmoji = "😊"
                }
            }
        }
    }
    
    @IBAction func changeVideoMirrorSwitch(_ sender: NSSwitch) {
        if previewLayer == nil { return }
        
        switch sender.state {
        case .off:
            previewLayer.connection?.isVideoMirrored = false
            videoMirrorLabel.textColor = NSColor.darkGray
        case .on:
            previewLayer.connection?.isVideoMirrored = true
            videoMirrorLabel.textColor = NSColor.systemBlue
        default:
            break
        }
    }
    
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    /*
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let err = error {
            print(err.localizedDescription)
            return
        }
     
        if let cgImage = photo.cgImageRepresentation() {
            
        }
    }*/
    
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection)
    {
        switch detectMode {
        case .none:
            DispatchQueue.main.async { self.removeAllFaceViews() }
        case .face:
            faceDetection(sampleBuffer: sampleBuffer)
        case .object:
            DispatchQueue.main.async { self.removeAllFaceViews() }
        }
    }
    
    
    // MARK: - Face Detection
    
    func faceDetection(sampleBuffer: CMSampleBuffer) {
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer,
                                                  key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
                                                  attachmentModeOut: nil)
        
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            options: requestHandlerOptions)
            
        try? handler.perform([request])
        
        guard let observations = request.results as? [VNFaceObservation] else {
            return
        }
        
        DispatchQueue.main.async {
            self.removeAllFaceViews()
            self.drawFaces(observations)
        }
    }
    
    func drawFaces(_ faceObservations: [VNFaceObservation]) {
        //print(faceObservations)
        
        for face in faceObservations {
            let facebounds = previewLayer.layerRectConverted(fromMetadataOutputRect: face.boundingBox)
            
            switch faceMask {
            case .rectangle:
                let faceView = NSView(frame: facebounds)
                faceView.wantsLayer = true
                faceView.layer?.backgroundColor = NSColor(red: 1, green: 45/255, blue: 45/255, alpha: 0.4).cgColor
                faceViews.append(faceView)
                self.view.addSubview(faceView)
            case .emoji:
                let faceView = NSImageView(frame: facebounds)
                faceView.image = emojiImage()
                faceViews.append(faceView)
                self.view.addSubview(faceView)
            }
        }
    }
    
    func removeAllFaceViews() {
        if faceViews.count <= 0 { return }
        
        for faceView in faceViews {
            faceView.removeFromSuperview()
        }
        faceViews.removeAll()
    }
    
    func emojiImage(width: Int = 512, height: Int = 512) -> NSImage? {
        guard width > 24,
              let drawingContext = CGContext(data: nil, width: width, height: height,
                                             bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        else {
            return nil
        }
        
        let imageSize = NSSize(width: width, height: height)
        let targetRect = NSRect(origin: .zero, size: imageSize)
        let font = NSFont.systemFont(ofSize: CGFloat(width - 24))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: drawingContext, flipped: false)
        NSString(string: faceEmoji).draw(in: targetRect, withAttributes: [.font: font])
        NSGraphicsContext.restoreGraphicsState()
        if let coreImage = drawingContext.makeImage() {
            return NSImage(cgImage: coreImage, size: imageSize)
        }
        return nil
    }
    
}

