//
//  CameraManager.swift
//  Privacy Invading Smart Glasses
//
//  Created by Gregor Finger on 27/10/2025.
//

import AVFoundation
import SwiftUI
import Combine

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
        }
    }
    
    func requestPermission() {
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            switch status {
            case .authorized:
                await MainActor.run {
                    isAuthorized = true
                }
                await setupCaptureSession()
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await MainActor.run {
                    isAuthorized = granted
                }
                if granted {
                    await setupCaptureSession()
                }
            case .denied, .restricted:
                await MainActor.run {
                    isAuthorized = false
                }
            @unknown default:
                await MainActor.run {
                    isAuthorized = false
                }
            }
        }
    }
    
    private func setupCaptureSession() async {
        // Run capture session setup on a background queue
        await Task.detached {
            self.captureSession.beginConfiguration()
            
            // Remove existing inputs
            self.captureSession.inputs.forEach { self.captureSession.removeInput($0) }
            
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
            
            let cameras = discoverySession.devices
            
            // Update UI on main actor
            await MainActor.run {
                self.availableCameras = cameras
            }
            
            // Prefer external camera (USB webcam) if available
            let preferredCamera = cameras.first { $0.deviceType == .external } 
                               ?? cameras.first
            
            guard let camera = preferredCamera else {
                print("No cameras available")
                self.captureSession.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    
                    // Update properties on main actor
                    await MainActor.run {
                        self.videoInput = input
                        self.currentCamera = camera
                    }
                    
                    // Set session preset for best quality
                    if self.captureSession.canSetSessionPreset(.high) {
                        self.captureSession.sessionPreset = .high
                    }
                }
            } catch {
                print("Error creating camera input: \(error.localizedDescription)")
            }
            
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
        }.value
    }
    
    func switchCamera(to camera: AVCaptureDevice) {
        Task {
            await Task.detached { [weak self] in
                guard let self = self else { return }
                
                self.captureSession.beginConfiguration()
                
                // Remove current input - need to get this on main actor
                let currentInput = await MainActor.run { self.videoInput }
                if let currentInput = currentInput {
                    self.captureSession.removeInput(currentInput)
                }
                
                do {
                    let newInput = try AVCaptureDeviceInput(device: camera)
                    
                    if self.captureSession.canAddInput(newInput) {
                        self.captureSession.addInput(newInput)
                        
                        // Update properties on main actor
                        await MainActor.run {
                            self.videoInput = newInput
                            self.currentCamera = camera
                        }
                    }
                } catch {
                    print("Error switching camera: \(error.localizedDescription)")
                }
                
                self.captureSession.commitConfiguration()
            }.value
        }
    }
    
    deinit {
        captureSession.stopRunning()
    }
}