# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS/macOS application built with SwiftUI that displays camera feeds with support for external USB webcams. The app prioritizes external cameras when available and allows runtime switching between multiple camera sources.

## Build & Test Commands

### Building
```bash
# Build for iOS Simulator
xcodebuild -scheme "Privacy Invading Smart Glasses" -sdk iphonesimulator -configuration Debug build

# Build for device
xcodebuild -scheme "Privacy Invading Smart Glasses" -sdk iphoneos -configuration Debug build

# Build release version
xcodebuild -scheme "Privacy Invading Smart Glasses" -configuration Release build
```

### Testing
```bash
# Run all tests
xcodebuild test -scheme "Privacy Invading Smart Glasses" -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test target
xcodebuild test -scheme "Privacy Invading Smart Glasses" -only-testing:Privacy_Invading_Smart_GlassesTests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -scheme "Privacy Invading Smart Glasses" -only-testing:Privacy_Invading_Smart_GlassesUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Running
Open `Privacy Invading Smart Glasses.xcodeproj` in Xcode and run with Cmd+R. The app requires camera permissions to function.

## Architecture

### Core Components

**CameraManager** (`CameraManager.swift`)
- `@MainActor` class managing AVFoundation capture session lifecycle
- Handles camera permission requests and authorization states
- Discovers all available cameras including external USB webcams via `AVCaptureDevice.DiscoverySession`
- Prioritizes external cameras (`.external` device type) over built-in cameras
- All capture session configuration happens on background threads via `Task.detached`, with UI updates posted to `@MainActor`
- Published properties: `isAuthorized`, `availableCameras`, `currentCamera`

**CameraPreviewView** (`CameraPreviewView.swift`)
- `UIViewRepresentable` wrapper around `AVCaptureVideoPreviewLayer`
- Custom `VideoPreviewView` UIView subclass with layer class override
- Configured with `.resizeAspectFill` gravity for full-screen display

**ContentView** (`ContentView.swift`)
- Main UI with camera preview, permission handling, and camera switching controls
- Uses `@StateObject` for CameraManager lifecycle
- Menu-based camera switcher in top-right overlay
- Permission request UI displayed when not authorized

### Threading Model

CameraManager uses strict actor isolation:
- All published properties and public methods are `@MainActor`
- AVCaptureSession configuration runs on background threads via `Task.detached`
- UI updates are explicitly posted back to `MainActor.run {}`
- This pattern prevents main thread blocking during camera setup/switching

### Camera Discovery & Selection

The app uses `AVCaptureDevice.DiscoverySession` with device types:
- `.external` (USB webcams - preferred)
- `.builtInWideAngleCamera`
- `.builtInUltraWideCamera`
- `.builtInTelephotoCamera`

External cameras are automatically selected when available. Users can switch between cameras via the rotate button menu.
