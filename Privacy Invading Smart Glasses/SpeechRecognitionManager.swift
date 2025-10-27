//
//  SpeechRecognitionManager.swift
//  Privacy Invading Smart Glasses
//
//  Created by Gregor Finger on 27/10/2025.
//

import Speech
import AVFoundation
import SwiftUI
import Combine

@MainActor
class SpeechRecognitionManager: NSObject, ObservableObject {
    @Published var recognizedText = ""
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var errorMessage: String?
    @Published var availableAudioInputs: [AVAudioSessionPortDescription] = []
    @Published var currentAudioInput: AVAudioSessionPortDescription?

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    override init() {
        super.init()
        // Initialize with the device's preferred language
        speechRecognizer = SFSpeechRecognizer()
        speechRecognizer?.delegate = self

        // Observe audio route changes (device plug/unplug)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc nonisolated private func handleAudioRouteChange(notification: Notification) {
        Task { @MainActor in
            print("Audio route changed, rediscovering inputs...")
            await discoverAudioInputs()
        }
    }
    
    func setup() {
        Task {
            await requestPermissions()
            await discoverAudioInputs()
        }
    }

    func discoverAudioInputs() async {
        let audioSession = AVAudioSession.sharedInstance()

        // Get available audio inputs
        let inputs = audioSession.availableInputs ?? []

        await MainActor.run {
            self.availableAudioInputs = inputs

            // Prefer USB/external microphones (from webcams)
            let externalInput = inputs.first { input in
                input.portType == .usbAudio
            }

            // Fallback to built-in mic if no external found
            self.currentAudioInput = externalInput ?? inputs.first

            print("Available audio inputs: \(inputs.map { "\($0.portName) (\($0.portType.rawValue))" })")
            if let current = self.currentAudioInput {
                print("Selected audio input: \(current.portName) (\(current.portType.rawValue))")
            }
        }
    }

    func selectAudioInput(_ input: AVAudioSessionPortDescription) {
        currentAudioInput = input
        print("Manually selected audio input: \(input.portName)")
    }

    func selectAudioInputMatchingCamera(_ camera: AVCaptureDevice) {
        // Try to find an audio input that matches the camera name
        // Many USB webcams expose both video and audio under similar names
        let cameraName = camera.localizedName.lowercased()

        let matchingInput = availableAudioInputs.first { input in
            let inputName = input.portName.lowercased()
            // Check if names share common words (e.g., "Logitech C920" camera with "Logitech C920" mic)
            return inputName.contains(cameraName) || cameraName.contains(inputName)
        }

        if let match = matchingInput {
            selectAudioInput(match)
            print("Auto-matched audio input '\(match.portName)' to camera '\(camera.localizedName)'")
        } else {
            print("No matching audio input found for camera '\(camera.localizedName)'")
        }
    }
    
    func requestPermissions() async {
        // Request speech recognition permission
        let speechAuthStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        // Request microphone permission
        let micAuthStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        isAuthorized = speechAuthStatus == .authorized && micAuthStatus
        
        if !isAuthorized {
            if speechAuthStatus != .authorized {
                errorMessage = "Speech recognition permission denied"
            } else if !micAuthStatus {
                errorMessage = "Microphone permission denied"
            }
        }
    }
    
    func startRecording() {
        guard isAuthorized else {
            errorMessage = "Permissions not granted"
            return
        }
        
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)

            // Set preferred audio input to external webcam mic if available
            if let preferredInput = currentAudioInput {
                try audioSession.setPreferredInput(preferredInput)
                print("Set preferred audio input to: \(preferredInput.portName)")
            }

            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session setup failed: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        // Use on-device recognition if available
        if let recognizer = speechRecognizer, recognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
            print("Using on-device speech recognition")
        } else {
            recognitionRequest.requiresOnDeviceRecognition = false
            print("Using server-based speech recognition")
        }
        
        // Get the audio input node
        let inputNode = audioEngine.inputNode
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                
                if error != nil || result?.isFinal == true {
                    // Stop recording if there's an error or final result
                    self.stopRecording()
                }
            }
        }
        
        // Install tap on audio input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            errorMessage = nil
        } catch {
            errorMessage = "Audio engine failed to start: \(error.localizedDescription)"
        }
    }
    
    nonisolated func stopRecording() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
            
            self.recognitionRequest?.endAudio()
            self.recognitionRequest = nil
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            
            self.isRecording = false
        }
    }
    
    func clearText() {
        recognizedText = ""
    }
    
    deinit {
        stopRecording()
        NotificationCenter.default.removeObserver(self)
    }
}

extension SpeechRecognitionManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.isAuthorized = false
                self.errorMessage = "Speech recognizer not available"
            }
        }
    }
}