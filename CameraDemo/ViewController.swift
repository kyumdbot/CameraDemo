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
    var detectMode = DetectMode.none
    var faceMask = FaceMask.rectangle
    var faceEmoji = "😊"
    let faceEmojiArray = ["😊", "☺️", "🥰", "😍", "😉", "😌", "😎", "😷",
                          "🥸", "😱", "🤫", "👺", "🤡", "🎃", "👽", "👀"]
    
    
    var objectViews = [NSView]()
    var objectRecognitionRequests = [VNRequest]()
    
    
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
        
        // setup CoreML Model
        setupObjectDetectionModel()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    
    // MARK: - Setup
    
    func hideVideoMirrorComponents() {
        videoMirrorSwitch.state = .off
        videoMirrorSwitch.isHidden = true
        videoMirrorLabel.isHidden = true
    }
    
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
        videoOutput.alwaysDiscardsLateVideoFrames = true
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
            faceMasksPopUpButton.isHidden = (detectMode == .face) ? false : true
            
            switch detectMode {
            case .object:
                break
            default:
                break
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
            DispatchQueue.main.async { self.removeAllObjectViews() }
        case .face:
            faceDetection(sampleBuffer: sampleBuffer)
        case .object:
            objectDetection(sampleBuffer: sampleBuffer)
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
            self.removeAllObjectViews()
            self.drawFaces(observations)
        }
    }
    
    func drawFaces(_ faceObservations: [VNFaceObservation]) {
        //print(faceObservations)
        
        for face in faceObservations {
            let facebounds = previewLayer.layerRectConverted(fromMetadataOutputRect: face.boundingBox)
            
            switch faceMask {
            case .rectangle:
                let view = NSView(frame: facebounds)
                view.wantsLayer = true
                view.layer?.backgroundColor = NSColor(red: 1, green: 45/255, blue: 45/255, alpha: 0.4).cgColor
                objectViews.append(view)
                self.view.addSubview(view)
            case .emoji:
                let view = NSImageView(frame: facebounds)
                view.image = emojiImage()
                objectViews.append(view)
                self.view.addSubview(view)
            }
        }
    }
    
    func removeAllObjectViews() {
        if objectViews.count <= 0 { return }
        
        for view in objectViews {
            view.removeFromSuperview()
        }
        objectViews.removeAll()
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
    
    
    // MARK: - Object Detection
    
    func setupObjectDetectionModel() {
        //
        // YOLOv3TinyFP16.mlmodel :
        //   Storing model weights using half-precision (16 bit) floating point numbers.
        //
        guard let modelURL = Bundle.main.url(forResource: "YOLOv3TinyFP16", withExtension: "mlmodelc") else {
            print(">> Model file is missing")
            return
        }
        
        do {
            let model = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
                DispatchQueue.main.async {
                    self.removeAllObjectViews()
                    if let results = request.results {
                        self.drawObjects(results)
                    }
                }
            })
            self.objectRecognitionRequests = [objectRecognition]
            
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
    }
    
    func objectDetection(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try imageRequestHandler.perform(self.objectRecognitionRequests)
        } catch {
            print(error)
        }
    }
    
    func drawObjects(_ objectObservations: [Any]) {
//        print(objectObservations)
        
        for observation in objectObservations where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            
            let topLabelObservation = objectObservation.labels[0]
            //print("topLabelObservation: \(topLabelObservation)")
            
            let objectBounds = previewLayer.layerRectConverted(fromMetadataOutputRect: objectObservation.boundingBox)
            let view = NSView(frame: objectBounds)
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor(red: 1, green: 211/255, blue: 6/255, alpha: 0.5).cgColor
            
            let name = topLabelObservation.identifier.prefix(1).uppercased() + topLabelObservation.identifier.dropFirst()
            let confidence = String(format: "%.2f", topLabelObservation.confidence)
            
            let textLabel = NSTextField(labelWithString: "\(name)\n\(confidence)")
            textLabel.textColor = NSColor.blue
            textLabel.font = NSFont.systemFont(ofSize: 18)
            textLabel.frame = view.bounds
            view.addSubview(textLabel)
            
            objectViews.append(view)
            self.view.addSubview(view)
        }
    }
    
}

