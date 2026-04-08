import Foundation
import AVFoundation
import AudioToolbox

class AudioRecorder {
    var onRMSUpdate: ((Float) -> Void)?

    var audioQueue: OpaquePointer?
    var isRecording = false

    // Envelope smoothing
    var smoothedRMS: Float = 0
    let attackCoeff: Float = 0.4
    let releaseCoeff: Float = 0.15

    private var audioFormat = AudioStreamBasicDescription(
        mSampleRate: 16000,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 1,
        mBitsPerChannel: 32,
        mReserved: 0
    )

    func start() {
        guard !isRecording else { return }
        isRecording = true
        smoothedRMS = 0

        var format = audioFormat
        var queue: OpaquePointer?
        let status = AudioQueueNewInput(&format, audioQueueCallback, Unmanaged.passUnretained(self).toOpaque(), nil, nil, 0, &queue)

        guard status == noErr, let audioQueueRef = queue else {
            print("AudioQueue creation failed: \(status)")
            isRecording = false
            return
        }

        self.audioQueue = audioQueueRef

        // Set input gain
        AudioQueueSetParameter(audioQueueRef, kAudioQueueParam_Volume, 1.0)

        // Allocate buffers
        let bufferSize: UInt32 = 3200 // 200ms at 16kHz
        for _ in 0..<3 {
            var buffer: AudioQueueBufferRef?
            AudioQueueAllocateBuffer(audioQueueRef, bufferSize, &buffer)
            if let buf = buffer {
                AudioQueueEnqueueBuffer(audioQueueRef, buf, 0, nil)
            }
        }

        AudioQueueStart(audioQueueRef, nil)
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        if let queue = audioQueue {
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }
        audioQueue = nil
    }
}

private func audioQueueCallback(
    _ userData: UnsafeMutableRawPointer?,
    _ queue: OpaquePointer,
    _ buffer: UnsafeMutablePointer<AudioQueueBuffer>,
    _ startTime: UnsafePointer<AudioTimeStamp>,
    _ numPackets: UInt32,
    _ packetDescs: UnsafePointer<AudioStreamPacketDescription>?
) {
    guard let userData = userData else { return }
    let recorder = Unmanaged<AudioRecorder>.fromOpaque(userData).takeUnretainedValue()

    guard recorder.isRecording else { return }

    let frameCount = Int(buffer.pointee.mAudioDataByteSize) / 4
    guard frameCount > 0 else { return }
    let audioData = buffer.pointee.mAudioData.assumingMemoryBound(to: Float.self)

    // Calculate RMS
    var sumSquares: Float = 0
    for i in 0..<frameCount {
        let sample = audioData[i]
        sumSquares += sample * sample
    }
    let rms = sqrt(sumSquares / Float(frameCount))

    // Apply envelope smoothing
    let coeff = rms > recorder.smoothedRMS ? recorder.attackCoeff : recorder.releaseCoeff
    recorder.smoothedRMS = recorder.smoothedRMS + coeff * (rms - recorder.smoothedRMS)

    // Scale for visual: typical mic RMS is very small, amplify significantly
    let amplifiedRMS = min(recorder.smoothedRMS * 50.0, 1.0)

    DispatchQueue.main.async {
        recorder.onRMSUpdate?(amplifiedRMS)
    }

    // Re-enqueue buffer
    if recorder.isRecording {
        AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
    }
}
