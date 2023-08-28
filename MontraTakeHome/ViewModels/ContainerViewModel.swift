//
//  ContainerViewModel.swift
//  MontraTakeHome
//
//  Created by Seun Olalekan on 2023-08-25.
//

import Foundation
import AVFoundation


class ContainerViewModel : NSObject, ObservableObject {
    
    private var session: AVCaptureSession = .init()
    private (set) var previewLayer: AVCaptureVideoPreviewLayer?
    
    /// Availbale Camera Sources from user's mac
    @Published private (set) var availableCameras : [AVCaptureDevice] = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
        mediaType: .video,
        position: .unspecified
    ).devices
    /// Current selected video camera
    @Published private (set) var selectedCamera : AVCaptureDevice? = AVCaptureDevice.default(for: .video)
    /// Name for current selected video camera
    @Published private (set) var selectedCameraTitle: String = "Select a Camera Source"
    /// Availbale Camera Sources from user's mac
    @Published private (set) var availableMics : [AVCaptureDevice] = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInMicrophone, .externalUnknown],
        mediaType: .audio,
        position: .unspecified
    ).devices
    /// Current selected video camera
    @Published private (set) var selectedMic : AVCaptureDevice? = AVCaptureDevice.default(for: .audio)
    /// Name for current selected video camera
    @Published private (set) var selectedMicTitle: String = "Select a Mic Source"
    @Published var isRecording: Bool = false
    @Published var alert: Bool = false
    
    private (set) var captureSession: AVCaptureSession = .init()
    
    private var videoOutput = AVCaptureVideoDataOutput()
    private var audioOutput = AVCaptureAudioDataOutput()
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioAssetWriterInput: AVAssetWriterInput?
    private var accumulatedVideoFrames: [CMSampleBuffer] = []
    private var accumulatedAudioSamples: [CMSampleBuffer] = []
    private var accumulatedDuration: CMTime = .zero
    private var fileDirectoryURL: URL?
    
    
    override init(){
        super.init()
        checkVideoAuthorizationStatus()
    }
    
    private func checkVideoAuthorizationStatus(){
        switch AVCaptureDevice.authorizationStatus(for: .video){
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                if status{
                    DispatchQueue.main.async {
                        self?.checkAudioAuthorizationStatus()
                    }
                }
            }
        case .restricted:
            return
        case .denied:
            alert.toggle()
        case .authorized:
            DispatchQueue.main.async { [weak self] in
                self?.checkAudioAuthorizationStatus()
            }
        @unknown default:
            return
        }
        
    }
    
    private func checkAudioAuthorizationStatus(){
        
        switch AVCaptureDevice.authorizationStatus(for: .audio){
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] status in
                if status{
                    DispatchQueue.main.async {
                        self?.configureCaptureSession()
                    }
                }
            }
        case .restricted:
            return
        case .denied:
            alert.toggle()
        case .authorized:
            DispatchQueue.main.async { [weak self] in
                self?.configureCaptureSession()
            }
        @unknown default:
            return
        }
        
    }
    
    private func configureCaptureSession(camera: AVCaptureDevice? = AVCaptureDevice.default(for: .video) , audio: AVCaptureDevice? = AVCaptureDevice.default(for: .audio) ) {
        
        // Configure video input
        guard let camera else { return }
        do {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("Error setting up video input: \(error)")
        }
        
        // Configure audio input
        guard let audio else { return }
        do {
            let audioInput = try AVCaptureDeviceInput(device: audio)
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }
        } catch {
            print("Error setting up audio input: \(error)")
        }
        
        // Configure video output
        videoOutput = AVCaptureVideoDataOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoOutputQueue"))
        }
        
        // Configure audio output
        audioOutput = AVCaptureAudioDataOutput()
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
            audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "AudioOutputQueue"))
        }
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    }
    
    
    func setAVDevices(with camera: AVCaptureDevice?, mic: AVCaptureDevice? ){
        if let camera, let mic {
            session.stopRunning()
            configureCaptureSession(camera: camera, audio: mic)
            selectedCamera = camera
            selectedCameraTitle = camera.localizedName
            selectedMic = mic
            selectedMicTitle = mic.localizedName
        }
    }
    
    
    func setupFileDirectory(){
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first{
            let chunksDirectory = documentsDirectory.appendingPathComponent("chunks")
            if !directoryExists(atPath: chunksDirectory.path){
                createChunksFolder()
            }else{
                fileDirectoryURL = chunksDirectory
            }
        }
    }
    
    private func createChunksFolder() {
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first{
            
            let chunksDirectory = documentsDirectory.appendingPathComponent("chunks")
            fileDirectoryURL = chunksDirectory
            
            do {
                try FileManager.default.createDirectory(at: chunksDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating 'chunks' folder: \(error.localizedDescription)")
            }
        }
    }
    
    private func directoryExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    func record() {
        setupFileDirectory()
        captureSession.startRunning()
    }
    
    func stopRecording() {
        captureSession.stopRunning()
    }
    
    
}

extension ContainerViewModel : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if output == videoOutput {
            accumulatedVideoFrames.append(sampleBuffer)
        } else if output == audioOutput {
            accumulatedAudioSamples.append(sampleBuffer)
        }
        
        accumulatedDuration = CMTimeAdd(accumulatedDuration, sampleBuffer.duration)
        
        if accumulatedDuration.seconds >= 1.0 {
            saveChunk()
            accumulatedVideoFrames.removeAll()
            accumulatedAudioSamples.removeAll()
            accumulatedDuration = .zero
        }
    }
    
    func saveChunk() {
        guard let fileDirectoryURL else {return}
        guard let firstFrame = accumulatedVideoFrames.first else {return}
        
        let outputURL = fileDirectoryURL.appendingPathComponent("chunk_\(Date().timeIntervalSince1970)")
        
        do {
             assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
            
            
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 640,
                AVVideoHeightKey: 480
            ])
            
            var channelLayout = AudioChannelLayout()
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_1_D

            let audioOutputSettings: [String : Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC_HE,
                AVSampleRateKey: 44100,
                AVChannelLayoutKey: NSData(bytes: &channelLayout, length: MemoryLayout.size(ofValue: channelLayout)),
            ]
            
            
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
            
            if let assetWriter, assetWriter.canAdd(videoInput), assetWriter.canAdd(audioInput){
                assetWriter.add(videoInput)
                assetWriter.add(audioInput)
            }
           
            
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(firstFrame))
            
            for (videoSample, audioSample) in zip(accumulatedVideoFrames, accumulatedAudioSamples) {
                    if assetWriter?.status == .writing {
                        if videoInput.isReadyForMoreMediaData && audioInput.isReadyForMoreMediaData {
                            videoInput.append(videoSample)
                            audioInput.append(audioSample)
                        }
                    } else {
                        break
                    }
                }
            
            videoInput.markAsFinished()
            audioInput.markAsFinished()
            
            assetWriter?.finishWriting {
                print("Video chunk saved at \(outputURL)")
            }
        }catch{
            print("Error combining frames: \(error)")
        }
    }
    
}




