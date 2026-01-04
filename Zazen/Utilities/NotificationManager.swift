//
//  NotificationManager.swift
//  Zazen
//
//  Created by Jake Sager on 1/4/26.
//

import UserNotifications
import AVFoundation

/// Manages local notifications for background bell sounds during meditation
final class NotificationManager {
    static let shared = NotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // Notification identifiers
    private let completionNotificationId = "zazen.meditation.completion"
    private let intervalNotificationPrefix = "zazen.meditation.interval."
    
    private init() {}
    
    // MARK: - Authorization
    
    /// Request notification permission
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    /// Check if notifications are authorized
    func isAuthorized() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    // MARK: - Scheduling
    
    /// Schedule all meditation notifications (completion bell and interval bells)
    func scheduleMeditationNotifications(
        duration: TimeInterval,
        bellSound: TimerSettings.BellSound,
        intervalMinutes: Int,
        intervalBellSound: TimerSettings.BellSound
    ) {
        // Cancel any existing meditation notifications first
        cancelAllMeditationNotifications()
        
        // Schedule completion notification
        if bellSound != .silence {
            scheduleCompletionNotification(in: duration, sound: bellSound)
        }
        
        // Schedule interval notifications
        if intervalMinutes > 0 && intervalBellSound != .silence {
            scheduleIntervalNotifications(
                totalDuration: duration,
                intervalMinutes: intervalMinutes,
                sound: intervalBellSound
            )
        }
    }
    
    /// Schedule the completion bell notification
    private func scheduleCompletionNotification(in seconds: TimeInterval, sound: TimerSettings.BellSound) {
        let content = UNMutableNotificationContent()
        content.title = "Meditation Complete"
        content.body = "Your meditation session has ended."
        content.categoryIdentifier = "MEDITATION_COMPLETE"
        
        // Set the custom sound
        if let soundName = SoundManager.shared.soundFileName(for: sound) {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        } else {
            content.sound = .default
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: completionNotificationId,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling completion notification: \(error)")
            }
        }
    }
    
    /// Schedule interval bell notifications
    private func scheduleIntervalNotifications(
        totalDuration: TimeInterval,
        intervalMinutes: Int,
        sound: TimerSettings.BellSound
    ) {
        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        var currentTime = intervalSeconds
        var intervalIndex = 0
        
        while currentTime < totalDuration {
            let content = UNMutableNotificationContent()
            content.title = "Interval Bell"
            content.body = "Mindfulness reminder"
            content.categoryIdentifier = "MEDITATION_INTERVAL"
            
            // Set the custom sound (softer for interval)
            if let soundName = SoundManager.shared.soundFileName(for: sound) {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
            } else {
                content.sound = .default
            }
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: currentTime, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(intervalNotificationPrefix)\(intervalIndex)",
                content: content,
                trigger: trigger
            )
            
            notificationCenter.add(request) { error in
                if let error = error {
                    print("Error scheduling interval notification: \(error)")
                }
            }
            
            currentTime += intervalSeconds
            intervalIndex += 1
        }
    }
    
    // MARK: - Cancellation
    
    /// Cancel all meditation-related notifications
    func cancelAllMeditationNotifications() {
        // Get all pending notifications and filter for our meditation ones
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            
            let meditationIds = requests
                .map { $0.identifier }
                .filter { $0 == self.completionNotificationId || $0.hasPrefix(self.intervalNotificationPrefix) }
            
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: meditationIds)
        }
    }
    
    /// Cancel only the completion notification (when meditation is ended early)
    func cancelCompletionNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [completionNotificationId])
    }
    
    /// Cancel all interval notifications from a certain point
    func cancelRemainingIntervalNotifications() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            
            let intervalIds = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(self.intervalNotificationPrefix) }
            
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: intervalIds)
        }
    }
}

