//
//  ContentView.swift
//  Privacy Invading Smart Glasses
//
//  Created by Gregor Finger on 27/10/2025.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var speechManager = SpeechRecognitionManager()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera feed background
                if cameraManager.isAuthorized {
                    CameraPreviewView(session: cameraManager.captureSession)
                        .ignoresSafeArea()
                } else {
                    // Permission request view
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("Camera Access Required")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Please allow camera access to view the external webcam feed.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Request Permission") {
                            cameraManager.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                
                // UI Overlay
                VStack {
                    // Top area - Camera switch button only
                    HStack {
                        Spacer()

                        Menu {
                            ForEach(cameraManager.availableCameras, id: \.uniqueID) { camera in
                                Button(camera.localizedName) {
                                    cameraManager.switchCamera(to: camera)
                                }
                            }
                        } label: {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 70, height: 70)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 40)

                    Spacer()

                    // Bottom area - Speech recognition with badges
                    HStack(alignment: .bottom, spacing: 16) {
                        // Left side - Fixed Close/Mic button
                        if speechManager.isRecording {
                            Button(action: {
                                speechManager.stopRecording()
                                speechManager.clearText()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundColor(.red)
                                    .frame(width: 70, height: 70)
                                    .glassEffect(.regular.interactive(), in: .circle)
                            }
                        } else {
                            Button(action: {
                                if speechManager.isAuthorized {
                                    speechManager.startRecording()
                                } else {
                                    Task {
                                        await speechManager.requestPermissions()
                                    }
                                }
                            }) {
                                Image(systemName: "mic")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 70, height: 70)
                                    .glassEffect(.regular.interactive(), in: .circle)
                            }
                            .disabled(!speechManager.isAuthorized)
                        }

                        // Right side - Badges and text in vertical stack
                        VStack(alignment: .leading, spacing: 16) {
                            // Camera and Microphone status badges
                            HStack(spacing: 12) {
                                // Camera badge
                                if let camera = cameraManager.currentCamera {
                                    HStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 14, weight: .medium))
                                        Text(camera.localizedName)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .glassEffect(.regular, in: .capsule)
                                }

                                // Microphone badge
                                if let mic = speechManager.currentAudioInput {
                                    HStack(spacing: 8) {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 14, weight: .medium))
                                        Text(mic.portName)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .glassEffect(.regular, in: .capsule)
                                }
                            }

                            // Text display when recording (dynamically sized)
                            if speechManager.isRecording && !speechManager.recognizedText.isEmpty {
                                HStack(spacing: 8) {
                                    Text(speechManager.recognizedText)
                                        .font(.system(size: 48, weight: .regular, design: .default))
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 24)
                                .glassEffect(.regular, in: .rect(cornerRadius: 35))
                            }
                        }
                    }
                    .padding(.leading, 40)
                    .padding(.trailing, 40)
                    .padding(.bottom, 60)
                }
                
                // Error message overlay
                if let errorMessage = speechManager.errorMessage {
                    VStack {
                        Spacer()
                        
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                            .padding(.horizontal, 30)
                            .padding(.bottom, 150)
                        
                        Spacer()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            cameraManager.setup()
            speechManager.setup()
        }
        .onChange(of: cameraManager.currentCamera) { oldCamera, newCamera in
            // When camera changes, try to match the microphone to the new camera
            if let camera = newCamera {
                speechManager.selectAudioInputMatchingCamera(camera)
            }
        }
    }
}

#Preview {
    ContentView()
}
