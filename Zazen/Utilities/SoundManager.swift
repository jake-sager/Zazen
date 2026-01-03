//
//  SoundManager.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import AVFoundation
import AudioToolbox

final class SoundManager: Sendable {
    static let shared = SoundManager()
    
    // File names for bundled sounds (without extension)
    // Sound files are in Zazen/Sounds/ folder
    private let soundFiles: [TimerSettings.BellSound: String] = [
        .bowlA: "tibetan-singing-bowl-low-trimmed",
        .bowlB: "tibetan-singing-bowl-struck-med-trimmed",
        .bowlC: "tibetan-singing-bowl-high"
    ]
    
    private let tickSoundFile = "volvo-signal-cleaned"
    
    private init() {}
    
    /// Configure audio session for background playback (call when starting meditation)
    func configureForBackgroundPlayback() {
        do {
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
    
    /// Plays the default completion sound
    func playCompletionSound() {
        playBellSound(.bowlB)
    }
    
    /// Plays a tick sound for picker scrolling
    func playTickSound() {
        // Try bundled sound first
        if let url = Bundle.main.url(forResource: tickSoundFile, withExtension: "wav") ??
                     Bundle.main.url(forResource: tickSoundFile, withExtension: "caf") ??
                     Bundle.main.url(forResource: tickSoundFile, withExtension: "m4a") {
            playFromURL(url, volume: 0.3)
        } else {
            // Fallback to system sound
            AudioServicesPlaySystemSound(1157)
        }
    }
    
    /// Plays a specific bell sound
    func playBellSound(_ sound: TimerSettings.BellSound, softer: Bool = false) {
        guard sound != .silence else { return }
        
        DispatchQueue.main.async {
            self.playBell(sound: sound, softer: softer)
        }
    }
    
    private func playBell(sound: TimerSettings.BellSound, softer: Bool) {
        // Ensure audio session is active
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
            return
        }
        
        // Play bundled sound
        if let fileName = soundFiles[sound],
           let url = Bundle.main.url(forResource: fileName, withExtension: "wav") ??
                     Bundle.main.url(forResource: fileName, withExtension: "caf") ??
                     Bundle.main.url(forResource: fileName, withExtension: "m4a") ??
                     Bundle.main.url(forResource: fileName, withExtension: "mp3") {
            playFromURL(url, volume: softer ? 0.5 : 1.0)
        } else {
            print("Sound file not found for: \(sound)")
        }
    }
    
    private func playFromURL(_ url: URL, volume: Float) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            keepAlive(player: player, for: player.duration + 0.5)
        } catch {
            print("Error playing sound from \(url): \(error)")
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
    
}
