//
//  SoundManager.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import AVFoundation

final class SoundManager: Sendable {
    static let shared = SoundManager()
    
    private init() {}
    
    /// Configure audio session for background playback (call when starting meditation)
    func configureForBackgroundPlayback() {
        do {
            // Use .playback category to play audio even when screen is locked
            // Don't use .mixWithOthers for background - we want full control
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: []
            )
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Background audio session error: \(error)")
        }
    }
    
    /// Plays the default completion sound (singing bowl)
    func playCompletionSound() {
        playBellSound(.singing)
    }
    
    /// Plays a specific bell sound
    func playBellSound(_ sound: TimerSettings.BellSound, softer: Bool = false) {
        DispatchQueue.main.async {
            self.generateAndPlay(sound: sound, softer: softer)
        }
    }
    
    private func generateAndPlay(sound: TimerSettings.BellSound, softer: Bool) {
        guard sound != .silence else { return }
        
        // Ensure audio session is active (for sounds when not in meditation)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
            return
        }
        
        // Generate audio on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let wavData: Data
            switch sound {
            case .singing:
                wavData = self.generateSingingBowl(softer: softer)
            case .tingsha:
                wavData = self.generateTingsha(softer: softer)
            case .woodBlock:
                wavData = self.generateWoodBlock(softer: softer)
            case .silence:
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let player = try AVAudioPlayer(data: wavData)
                    player.prepareToPlay()
                    player.play()
                    self.keepAlive(player: player, for: 5.0)
                } catch {
                    print("Playback error: \(error)")
                }
            }
        }
    }
    
    private func keepAlive(player: AVAudioPlayer, for seconds: Double) {
        objc_setAssociatedObject(
            self,
            Unmanaged.passUnretained(player).toOpaque(),
            player,
            .OBJC_ASSOCIATION_RETAIN
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            objc_setAssociatedObject(
                self,
                Unmanaged.passUnretained(player).toOpaque(),
                nil,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }
    
    // MARK: - Singing Bowl (warm, rich tone)
    
    private func generateSingingBowl(softer: Bool) -> Data {
        let sampleRate: Double = 44100
        let duration: Double = softer ? 2.5 : 4.0
        let totalSamples = Int(sampleRate * duration)
        let amplitude = softer ? 0.12 : 0.20
        
        let tones: [(freq: Double, amp: Double, delay: Double)] = [
            (528, amplitude, 0.0),
            (396, amplitude * 0.75, 0.2),
            (639, amplitude * 0.6, 0.4)
        ]
        
        var samples = [Float](repeating: 0, count: totalSamples)
        
        for (freq, amp, delay) in tones {
            for i in 0..<totalSamples {
                let time = Double(i) / sampleRate
                let t = time - delay
                guard t >= 0 else { continue }
                
                let f = freq * pow(0.995, t)
                let envelope = bellEnvelope(t: t, duration: duration - delay)
                let sample = sin(2.0 * .pi * f * t) * amp * envelope
                samples[i] += Float(sample)
            }
        }
        
        return normalizeAndCreateWAV(samples: samples, sampleRate: Int(sampleRate))
    }
    
    // MARK: - Tingsha (bright, clear)
    
    private func generateTingsha(softer: Bool) -> Data {
        let sampleRate: Double = 44100
        let duration: Double = softer ? 2.0 : 3.5
        let totalSamples = Int(sampleRate * duration)
        let amplitude = softer ? 0.10 : 0.18
        
        // Higher frequencies for bright tingsha sound
        let tones: [(freq: Double, amp: Double, delay: Double)] = [
            (2093, amplitude, 0.0),        // C7
            (2637, amplitude * 0.7, 0.05), // E7
            (3136, amplitude * 0.5, 0.1),  // G7
            (4186, amplitude * 0.3, 0.15)  // C8
        ]
        
        var samples = [Float](repeating: 0, count: totalSamples)
        
        for (freq, amp, delay) in tones {
            for i in 0..<totalSamples {
                let time = Double(i) / sampleRate
                let t = time - delay
                guard t >= 0 else { continue }
                
                // Quick attack, fast initial decay, then slow fade
                let envelope = tingshaEnvelope(t: t, duration: duration - delay)
                let f = freq * pow(0.999, t) // slight detuning
                let sample = sin(2.0 * .pi * f * t) * amp * envelope
                samples[i] += Float(sample)
            }
        }
        
        return normalizeAndCreateWAV(samples: samples, sampleRate: Int(sampleRate))
    }
    
    // MARK: - Wood Block (soft, percussive)
    
    private func generateWoodBlock(softer: Bool) -> Data {
        let sampleRate: Double = 44100
        let duration: Double = softer ? 0.4 : 0.6
        let totalSamples = Int(sampleRate * duration)
        let amplitude = softer ? 0.15 : 0.25
        
        // Wood block: short percussive with specific resonances
        let tones: [(freq: Double, amp: Double)] = [
            (800, amplitude),
            (1200, amplitude * 0.6),
            (1800, amplitude * 0.3)
        ]
        
        var samples = [Float](repeating: 0, count: totalSamples)
        
        for (freq, amp) in tones {
            for i in 0..<totalSamples {
                let time = Double(i) / sampleRate
                
                // Very fast attack, quick decay
                let attack: Double = 0.002
                let envelope: Double
                if time < attack {
                    envelope = time / attack
                } else {
                    envelope = pow(0.01, (time - attack) / (duration * 0.3))
                }
                
                let sample = sin(2.0 * .pi * freq * time) * amp * envelope
                samples[i] += Float(sample)
            }
        }
        
        // Add a bit of noise for wood character
        for i in 0..<min(Int(sampleRate * 0.02), totalSamples) {
            let noise = Float.random(in: -0.1...0.1)
            let envelope = 1.0 - Float(i) / Float(sampleRate * 0.02)
            samples[i] += noise * envelope * Float(amplitude)
        }
        
        return normalizeAndCreateWAV(samples: samples, sampleRate: Int(sampleRate))
    }
    
    // MARK: - Envelope Functions
    
    private func bellEnvelope(t: Double, duration: Double) -> Double {
        let attack: Double = 0.02
        let decay: Double = 0.3
        let sustainLevel: Double = 0.6
        let release = duration - 0.5
        
        if t < attack {
            return t / attack
        } else if t < attack + decay {
            let decayProgress = (t - attack) / decay
            return 1.0 - (1.0 - sustainLevel) * decayProgress
        } else if t < release {
            return sustainLevel
        } else {
            let releaseProgress = (t - release) / (duration - release)
            return sustainLevel * max(0, 1 - releaseProgress)
        }
    }
    
    private func tingshaEnvelope(t: Double, duration: Double) -> Double {
        let attack: Double = 0.005
        let decay1: Double = 0.1
        let decay1Level: Double = 0.4
        
        if t < attack {
            return t / attack
        } else if t < attack + decay1 {
            let progress = (t - attack) / decay1
            return 1.0 - (1.0 - decay1Level) * progress
        } else {
            let remaining = duration - attack - decay1
            let progress = (t - attack - decay1) / remaining
            return decay1Level * max(0.001, pow(1 - progress, 2))
        }
    }
    
    // MARK: - WAV Creation
    
    private func normalizeAndCreateWAV(samples: [Float], sampleRate: Int) -> Data {
        var normalizedSamples = samples
        if let maxVal = samples.map({ abs($0) }).max(), maxVal > 0.8 {
            let scale = 0.8 / maxVal
            normalizedSamples = samples.map { $0 * scale }
        }
        return createWAV(samples: normalizedSamples, sampleRate: sampleRate)
    }
    
    private func createWAV(samples: [Float], sampleRate: Int) -> Data {
        var data = Data()
        
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * 2)
        let fileSize = 36 + dataSize
        
        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        appendUInt32(&data, fileSize)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        
        // fmt chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        appendUInt32(&data, 16)
        appendUInt16(&data, 1)
        appendUInt16(&data, numChannels)
        appendUInt32(&data, UInt32(sampleRate))
        appendUInt32(&data, byteRate)
        appendUInt16(&data, blockAlign)
        appendUInt16(&data, bitsPerSample)
        
        // data chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        appendUInt32(&data, dataSize)
        
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clamped * Float(Int16.max - 1))
            appendInt16(&data, int16)
        }
        
        return data
    }
    
    private func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
    }
    
    private func appendUInt32(_ data: inout Data, _ value: UInt32) {
        var v = value.littleEndian
        data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
    }
    
    private func appendInt16(_ data: inout Data, _ value: Int16) {
        var v = value.littleEndian
        data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
    }
}
