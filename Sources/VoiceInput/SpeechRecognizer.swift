import Foundation
import Speech

class SpeechRecognizer {
    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var audioEngine: AVAudioEngine?
    private var isRecording = false

    func startRecognition(language: String) {
        guard !isRecording else { return }
        stopRecognition()

        let locale = Locale(identifier: language)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            onError?(NSError(domain: "VoiceInput", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available for \(language)"]))
            return
        }

        guard recognizer.isAvailable else {
            onError?(NSError(domain: "VoiceInput", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"]))
            return
        }

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = false
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard let format = AVAudioFormat(
            commonFormat: recordingFormat.commonFormat,
            sampleRate: recordingFormat.sampleRate,
            channels: 1,
            interleaved: recordingFormat.isInterleaved
        ) else {
            onError?(NSError(domain: "VoiceInput", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio format"]))
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            onError?(error)
            return
        }

        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    self.isRecording = false
                    self.onFinalResult?(text)
                } else {
                    self.onPartialResult?(text)
                }
            }

            if let error = error {
                self.isRecording = false
                self.onError?(error)
            }
        }
    }

    func stopRecognition() {
        isRecording = false

        if let audioEngine = audioEngine {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }
}
