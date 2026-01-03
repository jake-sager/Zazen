//
//  TimerView.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import SwiftUI
import UIKit

enum TimerState {
    case idle
    case running
    case completed
}

struct TimerView: View {
    @State private var timerState: TimerState = .idle
    @State private var remainingSeconds: Int = 0
    @State private var timer: Timer?
    @State private var initialDuration: Int = 0
    @State private var lastIntervalBell: Int = 0
    @State private var originalBrightness: CGFloat = 1.0
    @State private var isDimmed: Bool = false
    @State private var dimTimer: Timer?
    @State private var meditationEndTime: Date?
    
    @Environment(\.scenePhase) private var scenePhase
    
    var store: MeditationStore
    @ObservedObject var settings: TimerSettings
    
    // Time until screen dims (in seconds)
    private let dimDelay: TimeInterval = 30
    private let dimmedBrightness: CGFloat = 0.05
    
    var body: some View {
        ZStack {
            // Background with paper texture
            PaperTextureBackground()
                .ignoresSafeArea()
            
            // Main content
            if timerState == .idle {
                VStack(spacing: 0) {
                    // Scrollable content area
                    ScrollView {
                        VStack(spacing: 24) {
                            // Picker
                            pickerView
                                .padding(.top, 40)
                            
                            // Settings
                            settingsView
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100) // Space for button
                    }
                    
                    Spacer()
                    
                    // Fixed START button at bottom
                    Button(action: startTimer) {
                        Text("START")
                    }
                    .buttonStyle(NeumorphicButtonStyle())
                    .disabled(settings.hours == 0 && settings.minutes == 0 && settings.seconds == 0)
                    .opacity(settings.hours == 0 && settings.minutes == 0 && settings.seconds == 0 ? 0.35 : 1)
                    .padding(.bottom, 24)
                }
            } else if timerState == .running {
                runningView
                    .onTapGesture {
                        // Wake screen on tap
                        if isDimmed {
                            restoreBrightness()
                            scheduleDimming()
                        }
                    }
            }
            
            // Completion overlay
            if timerState == .completed {
                completionOverlay
            }
        }
        .onAppear {
            // Keep screen on during meditation
            UIApplication.shared.isIdleTimerDisabled = timerState == .running
        }
        .onChange(of: timerState) { _, newState in
            UIApplication.shared.isIdleTimerDisabled = newState == .running
            
            if newState == .running {
                scheduleDimming()
            } else {
                cancelDimming()
                restoreBrightness()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    // MARK: - Background/Foreground Handling
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard timerState == .running, let endTime = meditationEndTime else { return }
        
        switch phase {
        case .active:
            // App became active - recalculate remaining time
            let now = Date()
            if now >= endTime {
                // Timer should have completed while in background
                completeTimer()
            } else {
                let remaining = Int(endTime.timeIntervalSince(now))
                remainingSeconds = remaining
            }
        case .background:
            // App going to background - timer will continue via notifications
            break
        case .inactive:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Picker View
    
    private var pickerView: some View {
        HStack(spacing: 4) {
            // Hours
            VStack(spacing: 6) {
                CylindricalPicker(value: $settings.hours, range: 0..<24)
                    .onChange(of: settings.hours) { _, _ in settings.save() }
                Text("H")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.32)
                    .foregroundColor(Color.textMuted)
            }
            
            colonSeparator
            
            // Minutes
            VStack(spacing: 6) {
                CylindricalPicker(value: $settings.minutes, range: 0..<60)
                    .onChange(of: settings.minutes) { _, _ in settings.save() }
                Text("M")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.32)
                    .foregroundColor(Color.textMuted)
            }
            
            colonSeparator
            
            // Seconds
            VStack(spacing: 6) {
                CylindricalPicker(value: $settings.seconds, range: 0..<60)
                    .onChange(of: settings.seconds) { _, _ in settings.save() }
                Text("S")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.32)
                    .foregroundColor(Color.textMuted)
            }
        }
    }
    
    // MARK: - Running View
    
    private var runningView: some View {
        VStack {
            Spacer()
            
            Text(formatTime(remainingSeconds))
                .font(.system(size: 56, weight: .light, design: .default))
                .tracking(1.12)
                .foregroundColor(Color.textPrimary)
                .monospacedDigit()
            
            if isDimmed {
                Text("tap to brighten")
                    .font(.system(size: 13))
                    .foregroundColor(Color.textMuted.opacity(0.5))
                    .padding(.top, 20)
            }
            
            Spacer()
            
            Button(action: stopTimer) {
                Text("STOP")
            }
            .buttonStyle(NeumorphicButtonStyle(isDestructive: true))
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Settings View
    
    private var settingsView: some View {
        VStack(spacing: 12) {
            // Bell Sound
            VStack(alignment: .leading, spacing: 12) {
                Text("BELL SOUND")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.32)
                    .foregroundColor(Color.textMuted)
                
                HStack(spacing: 8) {
                    ForEach(TimerSettings.BellSound.allCases) { sound in
                        bellSoundButton(sound)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .neumorphicCard()
            
            // Interval Bell
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("INTERVAL BELL")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.32)
                        .foregroundColor(Color.textMuted)
                    
                    Spacer()
                    
                    Text(intervalLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(settings.intervalMinutes > 0 ? Color.textPrimary : Color.textMuted)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(min(settings.intervalMinutes, maxIntervalMinutes)) },
                        set: {
                            settings.intervalMinutes = Int($0)
                            settings.save()
                        }
                    ),
                    in: 0...Double(max(maxIntervalMinutes, 1)),
                    step: 1
                )
                .tint(Color.accentPrimary)
                .disabled(maxIntervalMinutes < 1)
                .onChange(of: maxIntervalMinutes) { _, newMax in
                    if settings.intervalMinutes > newMax {
                        settings.intervalMinutes = max(newMax, 0)
                        settings.save()
                    }
                }
                
                // Interval bell sound selector (only when interval is set)
                if settings.intervalMinutes > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("INTERVAL SOUND")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1.2)
                            .foregroundColor(Color.textMuted.opacity(0.8))
                        
                        HStack(spacing: 6) {
                            ForEach(TimerSettings.BellSound.allCases.filter { $0 != .silence }) { sound in
                                intervalBellSoundButton(sound)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .neumorphicCard()
            .animation(.easeInOut(duration: 0.2), value: settings.intervalMinutes > 0)
        }
    }
    
    private func bellSoundButton(_ sound: TimerSettings.BellSound) -> some View {
        Button(action: {
            settings.bellSound = sound
            settings.save()
            // Preview the sound
            if sound != .silence {
                SoundManager.shared.playBellSound(sound)
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: iconForSound(sound))
                    .font(.system(size: 18))
                
                Text(sound.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                settings.bellSound == sound ?
                    Color.accentPrimary.opacity(0.15) : Color.clear
            )
            .foregroundColor(
                settings.bellSound == sound ?
                    Color.accentPrimary : Color.textMuted
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func iconForSound(_ sound: TimerSettings.BellSound) -> String {
        switch sound {
        case .bowlA, .bowlB, .bowlC: return "bell.fill"
        case .silence: return "speaker.slash.fill"
        }
    }
    
    // MARK: - Interval Helpers
    
    private var totalTimerMinutes: Int {
        settings.hours * 60 + settings.minutes + (settings.seconds > 0 ? 1 : 0)
    }
    
    private var maxIntervalMinutes: Int {
        max(totalTimerMinutes / 2, 0)
    }
    
    private var intervalLabel: String {
        if maxIntervalMinutes < 1 {
            return "Set timer first"
        } else if settings.intervalMinutes == 0 {
            return "Off"
        } else {
            return "Every \(settings.intervalMinutes) min"
        }
    }
    
    private func intervalBellSoundButton(_ sound: TimerSettings.BellSound) -> some View {
        Button(action: {
            settings.intervalBellSound = sound
            settings.save()
            // Preview the sound
            SoundManager.shared.playBellSound(sound, softer: true)
        }) {
            VStack(spacing: 3) {
                Image(systemName: iconForSound(sound))
                    .font(.system(size: 14))
                
                Text(sound.rawValue)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
            .background(
                settings.intervalBellSound == sound ?
                    Color.accentPrimary.opacity(0.15) : Color.clear
            )
            .foregroundColor(
                settings.intervalBellSound == sound ?
                    Color.accentPrimary : Color.textMuted
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Completion Overlay
    
    private var completionOverlay: some View {
        ZStack {
            PaperTextureBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Text("Complete")
                    .font(.system(size: 24, weight: .medium))
                    .tracking(1.2)
                    .foregroundColor(Color.textPrimary)
                
                Text("tap to dismiss")
                    .font(.system(size: 13))
                    .foregroundColor(Color.textMuted)
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 60)
            .neumorphicCard()
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: timerState)
        .onTapGesture {
            dismissCompletion()
        }
    }
    
    // MARK: - Colon Separator
    
    private var colonSeparator: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.neumorphicCard)
                .frame(width: 6, height: 6)
                .shadow(color: Color.shadowDark, radius: 2, x: 1, y: 1)
                .shadow(color: Color.shadowLight, radius: 2, x: -1, y: -1)
            
            Circle()
                .fill(Color.neumorphicCard)
                .frame(width: 6, height: 6)
                .shadow(color: Color.shadowDark, radius: 2, x: 1, y: 1)
                .shadow(color: Color.shadowLight, radius: 2, x: -1, y: -1)
        }
        .frame(height: 180)
        .padding(.horizontal, 6)
        .offset(y: -12)
    }
    
    // MARK: - Screen Dimming
    
    private func scheduleDimming() {
        cancelDimming()
        originalBrightness = UIScreen.main.brightness
        
        dimTimer = Timer.scheduledTimer(withTimeInterval: dimDelay, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                isDimmed = true
            }
            UIScreen.main.brightness = dimmedBrightness
        }
    }
    
    private func cancelDimming() {
        dimTimer?.invalidate()
        dimTimer = nil
    }
    
    private func restoreBrightness() {
        if isDimmed {
            UIScreen.main.brightness = originalBrightness
            withAnimation {
                isDimmed = false
            }
        }
    }
    
    // MARK: - Timer Logic
    
    private func startTimer() {
        let totalSeconds = settings.hours * 3600 + settings.minutes * 60 + settings.seconds
        guard totalSeconds > 0 else { return }
        
        initialDuration = totalSeconds
        remainingSeconds = totalSeconds
        lastIntervalBell = totalSeconds
        meditationEndTime = Date().addingTimeInterval(TimeInterval(totalSeconds))
        timerState = .running
        
        // Configure audio session for background playback
        SoundManager.shared.configureForBackgroundPlayback()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 1 {
                remainingSeconds -= 1
                checkIntervalBell()
            } else {
                completeTimer()
            }
        }
        
        // Ensure timer fires in background
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func checkIntervalBell() {
        guard settings.intervalMinutes > 0 else { return }
        guard settings.intervalBellSound != .silence else { return }
        
        let intervalSeconds = settings.intervalMinutes * 60
        let elapsed = initialDuration - remainingSeconds
        
        // Check if we've passed an interval boundary
        if elapsed > 0 && elapsed % intervalSeconds == 0 && elapsed != initialDuration {
            SoundManager.shared.playBellSound(settings.intervalBellSound, softer: true)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerState = .idle
        remainingSeconds = 0
        meditationEndTime = nil
    }
    
    private func completeTimer() {
        timer?.invalidate()
        timer = nil
        meditationEndTime = nil
        
        // Save the session
        let session = MeditationSession(durationSeconds: initialDuration)
        store.addSession(session)
        
        // Play completion sound
        if settings.bellSound != .silence {
            SoundManager.shared.playBellSound(settings.bellSound)
        }
        
        withAnimation {
            timerState = .completed
        }
    }
    
    private func dismissCompletion() {
        withAnimation {
            timerState = .idle
        }
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

#Preview {
    TimerView(store: MeditationStore(), settings: TimerSettings())
}
