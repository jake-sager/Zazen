//
//  TimerView.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import SwiftUI
import UIKit
import ActivityKit

enum TimerState {
    case idle
    case running
    case overtime  // Timer completed but user continues meditating
    case completed
}

struct TimerView: View {
    @State private var timerState: TimerState = .idle
    @State private var remainingSeconds: Int = 0
    @State private var overtimeSeconds: Int = 0  // Track overtime
    @State private var timer: Timer?
    @State private var initialDuration: Int = 0
    @State private var originalBrightness: CGFloat = 1.0
    @State private var isDimmed: Bool = false
    @State private var dimTimer: Timer?
    @State private var meditationEndTime: Date?
    @State private var meditationStartTime: Date?
    
    @State private var lastSavedDurationSeconds: Int = 0
    @State private var lastSavedStreak: Int = 0
    
    @Environment(\.scenePhase) private var scenePhase
    
    var store: MeditationStore
    @ObservedObject var settings: TimerSettings
    @Binding var isSessionActive: Bool
    
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
                VStack(spacing: 24) {
                    // Picker
                    pickerView
                        .padding(.top, 40)
                    
                    // Settings
                    settingsView
                    
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
                .padding(.horizontal, 24)
            } else if timerState == .running {
                runningView
                    .onTapGesture {
                        // Wake screen on tap
                        if isDimmed {
                            restoreBrightness()
                            scheduleDimming()
                        }
                    }
            } else if timerState == .overtime {
                overtimeView
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
            UIApplication.shared.isIdleTimerDisabled = timerState == .running || timerState == .overtime
            
            // Request notification permission on first appearance
            Task {
                await NotificationManager.shared.requestAuthorization()
            }
        }
        .onDisappear {
            // Stop any playing sounds when leaving the view
            SoundManager.shared.stopAllSounds()
        }
        .onChange(of: timerState) { _, newState in
            UIApplication.shared.isIdleTimerDisabled = newState == .running || newState == .overtime
            isSessionActive = newState != .idle && newState != .completed
            
            if newState == .running || newState == .overtime {
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
        switch phase {
        case .active:
            if timerState == .running, let endTime = meditationEndTime {
                // App became active - recalculate remaining time
                let now = Date()
                if now >= endTime {
                    // Timer should have completed while in background
                    // Calculate how much overtime has passed
                    let overtimePassed = Int(now.timeIntervalSince(endTime))
                    overtimeSeconds = overtimePassed
                    transitionToOvertime()
                } else {
                    let remaining = Int(endTime.timeIntervalSince(now))
                    remainingSeconds = remaining
                }
            } else if timerState == .overtime, let endTime = meditationEndTime {
                // Recalculate overtime
                let now = Date()
                overtimeSeconds = Int(now.timeIntervalSince(endTime))
            }
        case .background:
            // Timer will continue via notifications
            // Stop any sounds that are currently playing (for test previews)
            if timerState == .idle {
                SoundManager.shared.stopAllSounds()
            }
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
            
            TabularTimerText(text: formatTime(remainingSeconds), fontSize: 92)
            
            if isDimmed {
                Text("tap to brighten")
                    .font(.system(size: 13))
                    .foregroundColor(Color.textMuted.opacity(0.5))
                    .padding(.top, 20)
            }
            
            Spacer()

            HStack(spacing: 12) {
                Button(action: { endSessionEarly(save: false) }) {
                    Text("DISCARD")
                }
                .buttonStyle(NeumorphicPillButtonStyle(kind: .destructive))

                Button(action: { endSessionEarly(save: true) }) {
                    Text("SAVE & END")
                }
                .buttonStyle(NeumorphicPillButtonStyle(kind: .primary))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Overtime View
    
    private var overtimeView: some View {
        VStack {
            Spacer()
            
            // Same timer display, just counting up with "+"
            TabularTimerText(text: "+\(formatTime(overtimeSeconds))", fontSize: 92)
            
            // Add overtime button - right beneath the timer
            Button(action: { finishOvertime(includeOvertime: true) }) {
                Text("ADD +\(formatTimeCompact(overtimeSeconds).uppercased())")
            }
            .buttonStyle(NeumorphicPillButtonStyle(kind: .secondary))
            .padding(.horizontal, 48)
            .padding(.top, 16)
            
            // Completed time note
            Text("\(formatTimeCompact(initialDuration)) completed")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.textMuted)
                .padding(.top, 12)
            
            if isDimmed {
                Text("tap to brighten")
                    .font(.system(size: 13))
                    .foregroundColor(Color.textMuted.opacity(0.5))
                    .padding(.top, 20)
            }
            
            Spacer()

            // Finish button (saves original time only)
            Button(action: { finishOvertime(includeOvertime: false) }) {
                Text("FINISH")
            }
            .buttonStyle(NeumorphicButtonStyle())
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
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .tracking(1.2)
                    .foregroundColor(Color.textPrimary)
                
                if lastSavedDurationSeconds > 0 {
                    Text("Meditated \(formatTime(lastSavedDurationSeconds))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.textMuted)
                }
                
                if lastSavedStreak > 0 {
                    Text("Streak: \(lastSavedStreak) \(lastSavedStreak == 1 ? "day" : "days")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.textSecondary)
                }
                
                Text("tap to dismiss")
                    .font(.system(size: 13))
                    .foregroundColor(Color.textMuted)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 54)
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
        
        isSessionActive = true
        lastSavedDurationSeconds = 0
        lastSavedStreak = 0
        overtimeSeconds = 0
        initialDuration = totalSeconds
        remainingSeconds = totalSeconds
        meditationStartTime = Date()
        meditationEndTime = Date().addingTimeInterval(TimeInterval(totalSeconds))
        timerState = .running
        
        // Configure audio session for background playback
        SoundManager.shared.configureForBackgroundPlayback()
        
        // Schedule notifications for background sounds
        NotificationManager.shared.scheduleMeditationNotifications(
            duration: TimeInterval(totalSeconds),
            bellSound: settings.bellSound,
            intervalMinutes: settings.intervalMinutes,
            intervalBellSound: settings.intervalBellSound
        )
        
        // Start Live Activity
        Task { @MainActor in
            LiveActivityManager.shared.startActivity(totalDuration: totalSeconds)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 1 {
                remainingSeconds -= 1
                checkIntervalBell()
                
                // Update Live Activity
                Task { @MainActor in
                    LiveActivityManager.shared.updateActivity(remainingSeconds: remainingSeconds)
                }
            } else {
                // Timer is done, transition to overtime
                transitionToOvertime()
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
        // Only play if app is in foreground (notifications handle background)
        if elapsed > 0 && elapsed % intervalSeconds == 0 && elapsed != initialDuration {
            SoundManager.shared.playBellSound(settings.intervalBellSound, softer: true)
        }
    }
    
    private func transitionToOvertime() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = 0
        
        // Play completion sound
        if settings.bellSound != .silence {
            SoundManager.shared.playBellSound(settings.bellSound)
        }
        
        withAnimation {
            timerState = .overtime
        }
        
        // Update Live Activity to overtime state
        Task { @MainActor in
            LiveActivityManager.shared.transitionToOvertime(overtimeSeconds: overtimeSeconds)
        }
        
        // Start overtime timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            overtimeSeconds += 1
            
            // Update Live Activity with overtime
            Task { @MainActor in
                LiveActivityManager.shared.transitionToOvertime(overtimeSeconds: overtimeSeconds)
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func finishOvertime(includeOvertime: Bool) {
        timer?.invalidate()
        timer = nil
        
        // Cancel any remaining notifications
        NotificationManager.shared.cancelAllMeditationNotifications()
        
        // End Live Activity
        Task { @MainActor in
            LiveActivityManager.shared.endActivity()
        }
        
        // Calculate total duration
        let totalDuration = includeOvertime ? (initialDuration + overtimeSeconds) : initialDuration
        
        // Save the session
        saveSession(durationSeconds: totalDuration)
        
        withAnimation {
            timerState = .completed
        }
    }
    
    private func completeTimer() {
        timer?.invalidate()
        timer = nil
        meditationEndTime = nil
        
        // Cancel any remaining notifications
        NotificationManager.shared.cancelAllMeditationNotifications()
        
        // Save the session
        saveSession(durationSeconds: initialDuration)
        
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
        lastSavedDurationSeconds = 0
        lastSavedStreak = 0
        overtimeSeconds = 0
        isSessionActive = false
        
        // Deactivate audio session
        SoundManager.shared.deactivateAudioSession()
    }
    
    private func endSessionEarly(save: Bool) {
        timer?.invalidate()
        timer = nil
        meditationEndTime = nil
        
        // Cancel all scheduled notifications
        NotificationManager.shared.cancelAllMeditationNotifications()
        
        // End Live Activity
        Task { @MainActor in
            LiveActivityManager.shared.endActivity()
        }
        
        let elapsed = max(initialDuration - remainingSeconds, 0)
        
        if save, elapsed > 0 {
            saveSession(durationSeconds: elapsed)
            withAnimation {
                timerState = .completed
            }
        } else {
            timerState = .idle
            isSessionActive = false
            SoundManager.shared.deactivateAudioSession()
        }
        
        remainingSeconds = 0
        overtimeSeconds = 0
    }
    
    private func saveSession(durationSeconds: Int) {
        let session = MeditationSession(durationSeconds: durationSeconds)
        store.addSession(session)
        lastSavedDurationSeconds = durationSeconds
        lastSavedStreak = store.currentStreak
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    private func formatTimeCompact(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        
        if h > 0 {
            return "\(h)h \(m)m"
        } else if m > 0 {
            return "\(m)m \(s)s"
        } else {
            return "\(s)s"
        }
    }
}

#Preview {
    TimerView(store: MeditationStore(), settings: TimerSettings(), isSessionActive: .constant(false))
}
