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
                    // Top area - Camera switch button
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
                        .padding(.top, 60)
                        .padding(.trailing, 40)
                    }
                    
                    Spacer()
                    
                    // Bottom area - Speech recognition
                    VStack(spacing: 0) {
                        Spacer()

                        // Large text display when speech is active
                        if speechManager.isRecording && !speechManager.recognizedText.isEmpty {
                            HStack {
                                Text(speechManager.recognizedText)
                                    .font(.system(size: 40, weight: .regular, design: .default))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 50)
                                    .glassEffect(.regular, in: .rect(cornerRadius: 32))

                                Spacer()
                            }
                            .padding(.horizontal, 40)
                            .padding(.bottom, 140)
                        }

                        // Bottom controls
                        HStack {
                            // Speech/Close button
                            Button(action: {
                                if speechManager.isRecording {
                                    speechManager.stopRecording()
                                    speechManager.clearText()
                                } else {
                                    if speechManager.isAuthorized {
                                        speechManager.startRecording()
                                    } else {
                                        // Use Task to handle async call properly
                                        Task {
                                            await speechManager.requestPermissions()
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: speechManager.isRecording ? "xmark" : "mic")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundColor(speechManager.isRecording ? .red : .primary)
                                    .frame(width: 70, height: 70)
                                    .glassEffect(.regular.interactive(), in: .circle)
                            }
                            .disabled(!speechManager.isAuthorized && !speechManager.isRecording)
                            .padding(.leading, 40)

                            Spacer()
                        }
                        .padding(.bottom, 60)
                    }
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
        .onAppear {
            cameraManager.setup()
            speechManager.setup()
        }
    }
}

#Preview {
    ContentView()
}
