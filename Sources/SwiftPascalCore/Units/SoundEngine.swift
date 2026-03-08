import AVFoundation
import Foundation

/// Generates simple square-wave tones at specified frequencies, like the PC speaker.
/// The audio engine stays alive once created. Sound/NoSound just toggle the frequency.
@MainActor
public class SoundEngine {
    // Audio render state — accessed from the audio render thread.
    nonisolated(unsafe) private static var state = AudioState()

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var engineReady = false

    private class AudioState {
        var frequency: Double = 0  // 0 = silent
        var phase: Double = 0
    }

    public init() {
        setupEngine()
    }

    private func setupEngine() {
        let state = SoundEngine.state
        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let sampleRate = mainMixer.outputFormat(forBus: 0).sampleRate
        let renderFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        let node = AVAudioSourceNode(format: renderFormat) { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let freq = state.frequency

            for frame in 0..<Int(frameCount) {
                let sample: Float
                if freq > 0 {
                    sample = state.phase.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 0.15 : -0.15
                    state.phase += freq / sampleRate
                } else {
                    sample = 0
                }

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: mainMixer, format: renderFormat)

        do {
            try engine.start()
            audioEngine = engine
            sourceNode = node
            engineReady = true
        } catch {
            // Non-fatal
        }
    }

    public func sound(frequency: Int) {
        if !engineReady { setupEngine() }
        SoundEngine.state.frequency = Double(frequency)
        SoundEngine.state.phase = 0
    }

    public func noSound() {
        SoundEngine.state.frequency = 0
    }
}
