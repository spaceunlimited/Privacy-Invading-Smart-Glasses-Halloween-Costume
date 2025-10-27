//
//  CameraManager.swift
//  Privacy Invading Smart Glasses
//
//  Created by Gregor Finger on 27/10/2025.
//

import AVFoundation
import SwiftUI

@MainActor
class CameraManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var currentCamera: AVCaptureDevice?
    
    let captureSession = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
    
    func setup() {
        Task {
            await requestPermission()
            if isAuthorized {
                await setupCaptureSession()
            }
        }
    }
    
    func requestPermission() {
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            switch status {
            case .authorized:
                isAuthorized = true
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                isAuthorized = granted
            case .denied, .restricted:
                isAuthorized = false
            @unknown default:
                isAuthorized = false
            }
            
            if isAuthorized {
                await setupCaptureSession()
            }
        }
    }
    
    private func setupCaptureSession() async {
        captureSession.beginConfiguration()
        
        // Remove existing inputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        
        // Discover all available cameras (including external USB webcams)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .external // This captures USB webcams
            ],
            mediaType: .video,
            position: .unspecified
        )
        
        availableCameras = discoverySession.devices
        
        // Prefer external camera (USB webcam) if available
        let preferredCamera = availableCameras.first { $0.deviceType == .external } 
                           ?? availableCameras.first
        
        guard let camera = preferredCamera else {
            print("No cameras available")
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                videoInput = input
                currentCamera = camera
                
                // Set session preset for best quality
                if captureSession.canSetSessionPreset(.high) {
                    captureSession.sessionPreset = .high
                }
            }
        } catch {
            print("Error creating camera input: \(error.localizedDescription)")
        }
        
        captureSession.commitConfiguration()
        
        // Start the session on a background queue
        Task.detached {
            self.captureSession.startRunning()
        }
    }
    
    func switchCamera(to camera: AVCaptureDevice) {
        Task {
            captureSession.beginConfiguration()
            
            // Remove current input
            if let currentInput = videoInput {
                captureSession.removeInput(currentInput)
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: camera)
                
                if captureSession.canAddInput(newInput) {
                    captureSession.addInput(newInput)
                    videoInput = newInput
                    currentCamera = camera
                }
            } catch {
                print("Error switching camera: \(error.localizedDescription)")
            }
            
            captureSession.commitConfiguration()
        }
    }
    
    deinit {
        captureSession.stopRunning()
    }
}