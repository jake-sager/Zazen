//
//  SoundManager.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import AVFoundation
import AudioToolbox

final class SoundManager {
    static let shared = SoundManager()
    
    // File names for bundled sounds (without extension)
    // Sound files are in Zazen/Sounds/ folder
    private let soundFiles: [TimerSettings.BellSound: String] = [
        .bowlA: "tibetan-singing-bowl-low-trimmed",
        .bowlB: "tibetan-singing-bowl-struck-med-trimmed",
        .bowlC: "tibetan-singing-bowl-high"
    ]

    // Notification-safe versions (without extension). These are separate files so we never
    // need to modify your original audio assets, and so notification playback is reliable.
    // (iOS notification sounds have strict format/duration requirements.)
    private let notificationSoundFiles: [TimerSettings.BellSound: String] = [
        .bowlA: "tibetan-singing-bowl-low-trimmed-notif",
        .bowlB: "tibetan-singing-bowl-struck-med-trimmed-notif",
        .bowlC: "tibetan-singing-bowl-high-notif"
    ]
    
    private let tickSoundFile = "volvo-signal-cleaned"

    // A short silent audio file used to keep the app alive in the background during a session
    // (so interval bells can play on the lock screen without using notifications).
    private let silentLoopFile = "silence-1s"
    
    // Track active players so we can stop them
    private var activePlayers: [AVAudioPlayer] = []
    private let playerQueue = DispatchQueue(label: "com.zazen.soundmanager")

    // Background keep-alive player (loops silence)
    private var backgroundKeepAlivePlayer: AVAudioPlayer?
    
    private init() {}
    
    /// Configure audio session for background playback (call when starting meditation)
    func configureForBackgroundPlayback() {
        do {
            // Use .playback category without mixWithOthers for reliable background audio
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

    /// Start looping silent audio to keep the app alive in the background during an active session.
    /// This avoids using local notifications (no banners), while still allowing interval bells to play.
    func startBackgroundKeepAliveAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error activating audio session for keep-alive: \(error)")
        }

        guard backgroundKeepAlivePlayer == nil else { return }
        guard let url = Bundle.main.url(forResource: silentLoopFile, withExtension: "wav") else {
            print("Keep-alive silent audio not found: \(silentLoopFile).wav")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            // Non-zero but effectively inaudible. Some devices may not keep a 0-volume player active.
            player.volume = 0.001
            player.numberOfLoops = -1
            player.prepareToPlay()
            player.play()
            backgroundKeepAlivePlayer = player
        } catch {
            print("Error starting keep-alive audio: \(error)")
        }
    }

    /// Stop the silent keep-alive loop.
    func stopBackgroundKeepAliveAudio() {
        backgroundKeepAlivePlayer?.stop()
        backgroundKeepAlivePlayer = nil
    }
    
    /// Deactivate audio session when meditation is done
    func deactivateAudioSession() {
        stopBackgroundKeepAliveAudio()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error deactivating audio session: \(error)")
        }
    }
    
    /// Stop all currently playing sounds
    func stopAllSounds() {
        stopBackgroundKeepAliveAudio()
        playerQueue.sync {
            for player in activePlayers {
                player.stop()
            }
            activePlayers.removeAll()
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
    
    /// Get the file URL for a bell sound
    func soundFileURL(for sound: TimerSettings.BellSound) -> URL? {
        guard let fileName = soundFiles[sound] else { return nil }
        return Bundle.main.url(forResource: fileName, withExtension: "wav") ??
               Bundle.main.url(forResource: fileName, withExtension: "caf") ??
               Bundle.main.url(forResource: fileName, withExtension: "m4a") ??
               Bundle.main.url(forResource: fileName, withExtension: "mp3")
    }
    
    /// Get the file name for a bell sound (for notifications)
    func notificationSoundFileName(for sound: TimerSettings.BellSound) -> String? {
        guard sound != .silence else { return nil }
        let baseName = notificationSoundFiles[sound] ?? soundFiles[sound]
        guard let baseName else { return nil }
        return "\(baseName).wav"
    }
    
    private func playBell(sound: TimerSettings.BellSound, softer: Bool) {
        // Ensure audio session is active
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
            return
        }
        
        // Play bundled sound
        if let url = soundFileURL(for: sound) {
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
            
            // Track the player
            playerQueue.sync {
                activePlayers.append(player)
            }
            
            // Remove from active players when done
            let duration = player.duration + 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.playerQueue.sync {
                    self?.activePlayers.removeAll { $0 === player }
                }
            }
            
            keepAlive(player: player, for: duration)
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
