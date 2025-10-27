# Speaker Diarization Implementation Plan

## Overview
This document outlines the approach for adding speaker identification (speaker diarization) to the Privacy Invading Smart Glasses app using FluidAudio.

## Current Limitation (as of October 2025)
FluidAudio does **not yet support streaming ASR (speech-to-text)**. Their README states: "Streaming Support: Coming soon — batch processing is recommended for production use."

## Recommended Hybrid Approach

### Architecture
Use a **hybrid system** combining:
1. **Apple SFSpeechRecognizer** - Real-time speech-to-text transcription (existing)
2. **FluidAudio Streaming Diarization** - Real-time speaker identification (new)

### Why Hybrid?
- SFSpeechRecognizer: Provides live streaming transcription (required for real-time use)
- FluidAudio: Provides speaker diarization in streaming mode (identifies who is speaking)
- Both process the same audio stream simultaneously
- Outputs are combined: transcribed text + speaker labels

## Implementation Steps

### Phase 1: Setup & Dependencies
1. Add FluidAudio Swift Package dependency
   - GitHub: https://github.com/FluidInference/FluidAudio
   - Minimum iOS version: iOS 17+ (verify)

2. Download speaker diarization models on first launch
   - Models auto-download from HuggingFace
   - Store locally for offline use
   - Handle download progress/errors

### Phase 2: Create Speaker Diarization Manager
3. Create new file: `SpeakerDiarizationManager.swift`
   ```swift
   @MainActor
   class SpeakerDiarizationManager: ObservableObject {
       @Published var currentSpeaker: String = "Unknown"
       @Published var speakerSegments: [(speaker: String, start: Double, end: Double)] = []

       // FluidAudio streaming diarizer
       private var diarizer: DiarizerManager?
   }
   ```

4. Initialize FluidAudio's streaming diarizer
   ```swift
   let models = try await DiarizerModels.downloadIfNeeded()
   diarizer = DiarizerManager()
   diarizer.initialize(models: models)
   ```

### Phase 3: Audio Pipeline Integration
5. Share audio buffer between both managers
   - Option A: Modify `SpeechRecognitionManager` to also feed `SpeakerDiarizationManager`
   - Option B: Create unified `AudioManager` that feeds both systems

6. Ensure audio format compatibility
   - FluidAudio requires: **16 kHz mono**
   - Check current format from `AVAudioEngine.inputNode`
   - Convert if necessary using `AVAudioConverter`

7. Process audio in real-time
   ```swift
   // In audio tap callback
   inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
       // Send to SFSpeechRecognizer (existing)
       recognitionRequest.append(buffer)

       // Convert and send to FluidAudio diarization (new)
       let samples = convertToMono16kHz(buffer)
       let result = try diarizer.performCompleteDiarization(samples)

       // Update current speaker
       updateCurrentSpeaker(from: result)
   }
   ```

### Phase 4: Synchronization
8. Match timestamps between transcription and speaker labels
   - SFSpeechRecognizer provides timestamps for words
   - FluidAudio provides timestamps for speaker segments
   - Correlate them to attribute text to speakers

9. Handle edge cases
   - Speaker transitions mid-sentence
   - Overlapping speech
   - Unknown/uncertain speakers
   - No speech detected

### Phase 5: UI Updates
10. Modify ContentView to show speaker information
    - Add speaker badge/label (e.g., "Speaker 1:", "Speaker 2:")
    - Option: Color-code different speakers
    - Option: Show speaker icon alongside text

11. Example UI layout:
    ```
    [Camera Badge] [Mic Badge]

    [X Button]  [Speaker 1: "Recognized text goes here..."]
    ```

### Phase 6: Testing & Optimization
12. Test scenarios:
    - Single speaker continuous speech
    - Multiple speakers taking turns
    - Rapid speaker changes
    - Background noise
    - External webcam microphone vs built-in mic

13. Performance monitoring:
    - CPU usage with two ML models
    - Battery impact
    - Latency between speech and speaker ID
    - Memory usage

## Technical Considerations

### Audio Format Requirements
- **Current setup**: Format from `AVAudioEngine.inputNode.outputFormat(forBus: 0)`
- **FluidAudio needs**: 16 kHz mono PCM
- **Conversion needed**: Likely yes, use `AVAudioConverter`

### Performance Impact
- Running two ML models simultaneously:
  1. Apple Speech Recognition (on-device/server-based)
  2. FluidAudio Diarization (CoreML on Apple Neural Engine)
- Expected impact: Moderate CPU/battery usage
- Mitigation: Make speaker diarization optional/toggleable

### Privacy & Offline Operation
- ✅ All processing happens on-device
- ✅ No internet required after model download
- ✅ No data sent to servers (if using on-device speech recognition)

## Alternative Future Approach

### If/When FluidAudio Adds Streaming ASR
Once FluidAudio releases streaming ASR support:

**Option: Replace SFSpeechRecognizer entirely**
- Use FluidAudio for both transcription AND diarization
- Single ML pipeline, better integration
- Benefits:
  - Fully offline (no Apple server option)
  - Built-in speaker attribution
  - Multilingual support (25 European languages)
  - Single dependency

**Migration steps:**
1. Replace `SpeechRecognitionManager` with FluidAudio ASR manager
2. Integrate speaker diarization into same pipeline
3. Update UI to show combined results
4. Remove Speech framework dependency

Monitor FluidAudio GitHub releases and Discord for streaming ASR announcements.

## Resources

- FluidAudio GitHub: https://github.com/FluidInference/FluidAudio
- FluidAudio Blog Post: https://iosdev.tools/blog/fluidaudio/
- Apple Speech Framework: https://developer.apple.com/documentation/speech
- Audio Format Conversion: https://developer.apple.com/documentation/avfaudio/avaudioconverter

## Status
**Not yet implemented** - Documented for future enhancement

Last updated: October 27, 2025
