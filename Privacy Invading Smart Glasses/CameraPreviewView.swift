//
//  CameraPreviewView.swift
//  Privacy Invading Smart Glasses
//
//  Created by Gregor Finger on 27/10/2025.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    @State private var orientation = UIDevice.current.orientation
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // Force update orientation when view updates or orientation changes
        uiView.forceUpdateVideoOrientation()
    }
}

class VideoPreviewView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session = session else { return }
            videoPreviewLayer.session = session
            updateVideoOrientation()
        }
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        videoPreviewLayer.videoGravity = .resizeAspectFill
        updateVideoOrientation()
    }
    
    private func updateVideoOrientation() {
        // Add a small delay to ensure connection is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.performVideoOrientationUpdate()
        }
    }
    
    private func performVideoOrientationUpdate() {
        guard let connection = videoPreviewLayer.connection,
              connection.isVideoOrientationSupported else { 
            print("Video orientation not supported or no connection - will retry")
            // Retry after a short delay if connection isn't ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.performVideoOrientationUpdate()
            }
            return 
        }
        
        // Get the current device orientation
        let deviceOrientation = UIDevice.current.orientation
        let orientation: AVCaptureVideoOrientation
        
        // Use raw values to determine orientation
        print("Device orientation raw value: \(deviceOrientation.rawValue)")
        
        switch deviceOrientation.rawValue {
        case 1: // UIDeviceOrientation.portrait
            orientation = .portrait
        case 2: // UIDeviceOrientation.portraitUpsideDown
            orientation = .portraitUpsideDown
        case 3: // UIDeviceOrientation.landscapeLeft
            orientation = .landscapeRight // Camera sensor is rotated
        case 4: // UIDeviceOrientation.landscapeRight
            orientation = .landscapeLeft  // Camera sensor is rotated
        case 5, 6: // faceUp or faceDown
            // Use screen bounds to determine orientation when device is flat
            let screenBounds = UIScreen.main.bounds
            if screenBounds.width > screenBounds.height {
                orientation = .landscapeRight
                print("Using fallback: landscape (device flat, screen wide)")
            } else {
                orientation = .portrait
                print("Using fallback: portrait (device flat, screen tall)")
            }
        default: // unknown
            // Use view bounds as last resort
            let bounds = self.bounds
            if bounds.width > bounds.height {
                orientation = .landscapeRight
                print("Using fallback: landscape (bounds-based)")
            } else {
                orientation = .portrait
                print("Using fallback: portrait (bounds-based)")
            }
        }
        
        print("Setting video orientation to: \(orientation)")
        connection.videoOrientation = orientation
        
        // Force the layer to update
        videoPreviewLayer.setNeedsLayout()
        videoPreviewLayer.layoutIfNeeded()
    }
    
    // Public method to force orientation update
    func forceUpdateVideoOrientation() {
        updateVideoOrientation()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        // Listen for device orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // Listen for interface orientation changes (more reliable for app UI)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIApplication.didChangeStatusBarOrientationNotification,
            object: nil
        )
        
        // Start monitoring device orientation
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
    
    @objc private func orientationDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateVideoOrientation()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}