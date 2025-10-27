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
    @State private var showingTranscription = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if cameraManager.isAuthorized {
                    CameraPreviewView(session: cameraManager.captureSession)
                        .ignoresSafeArea()
                } else {
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
                
                // Speech transcription overlay
                if showingTranscription && !speechManager.recognizedText.isEmpty {
                    VStack {
                        Spacer()
                        
                        ScrollView {
                            Text(speechManager.recognizedText)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .padding()
                                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                        }
                        .frame(maxHeight: 200)
                        .animation(.easeInOut(duration: 0.3), value: speechManager.recognizedText)
                    }
                }
                
                // Control overlay
                VStack {
                    HStack {
                        // Speech recognition controls
                        VStack(spacing: 8) {
                            Button(action: {
                                if speechManager.isRecording {
                                    speechManager.stopRecording()
                                } else {
                                    speechManager.startRecording()
                                }
                            }) {
                                Image(systemName: speechManager.isRecording ? "mic.fill" : "mic")
                                    .font(.title2)
                                    .foregroundColor(speechManager.isRecording ? .red : .white)
                                    .padding()
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .disabled(!speechManager.isAuthorized)
                            
                            if speechManager.isRecording {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(speechManager.isRecording ? 1.0 : 0.0)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: speechManager.isRecording)
                            }
                        }
                        
                        Spacer()
                        
                        // Camera switching menu
                        Menu {
                            ForEach(cameraManager.availableCameras, id: \.uniqueID) { camera in
                                Button(camera.localizedName) {
                                    cameraManager.switchCamera(to: camera)
                                }
                            }
                        } label: {
                            Image(systemName: "camera.rotate")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding()
                    }
                    .padding(.top)
                    
                    Spacer()
                    
                    // Bottom controls
                    HStack {
                        // Clear transcription
                        if !speechManager.recognizedText.isEmpty {
                            Button("Clear") {
                                speechManager.clearText()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        
                        Spacer()
                        
                        // Toggle transcription visibility
                        Button(action: {
                            showingTranscription.toggle()
                        }) {
                            Image(systemName: showingTranscription ? "eye.fill" : "eye.slash.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .padding(.bottom, 40)
                    .padding(.horizontal)
                }
                
                // Error message overlay
                if let errorMessage = speechManager.errorMessage {
                    VStack {
                        Spacer()
                        
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                            .padding()
                        
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
