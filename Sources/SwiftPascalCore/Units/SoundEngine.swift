import AVFoundation
import Foundation

/// Generates simple square-wave tones at specified frequencies, like the PC speaker.
@MainActor
public class SoundEngine {
    // Shared mutable state accessed from the audio render thread.
    // Using a class with nonisolated(unsafe) so the render callback can read/write it.
    nonisolated(unsafe) private static var shared = AudioState()

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var isPlaying = false

    private class AudioState {
        var frequency: Double = 0
        var phase: Double = 0
        var volume: Float = 0.15
    }

    public init() {}

    public func sound(frequency: Int) {
        let freq = Double(frequency)
        guard freq > 0 else {
            noSound()
            return
        }

        SoundEngine.shared.frequency = freq

        if isPlaying { return }  // Already playing, just update frequency

        SoundEngine.shared.phase = 0
        let state = SoundEngine.shared

        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let freq = state.frequency
            let volume = state.volume

            for frame in 0..<Int(frameCount) {
                // Square wave for authentic PC speaker sound
                let sample = state.phase.truncatingRemainder(dividingBy: 1.0) < 0.5
                    ? volume : -volume
                state.phase += freq / sampleRate

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: mainMixer, format: outputFormat)

        do {
            try engine.start()
            audioEngine = engine
            sourceNode = node
            isPlaying = true
        } catch {
            // Sound failure is non-fatal
        }
    }

    public func noSound() {
        SoundEngine.shared.frequency = 0
        audioEngine?.stop()
        audioEngine = nil
        sourceNode = nil
        isPlaying = false
    }
}
