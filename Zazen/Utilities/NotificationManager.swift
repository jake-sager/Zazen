//
//  NotificationManager.swift
//  Zazen
//
//  Created by Jake Sager on 1/4/26.
//

import UserNotifications
import AVFoundation

/// Manages local notifications for background bell sounds during meditation
/// Note: These notifications are sound-only with no visible banner/alert
final class NotificationManager {
    static let shared = NotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // Notification identifiers
    private let completionNotificationId = "zazen.meditation.completion"
    private let intervalNotificationPrefix = "zazen.meditation.interval."
    
    private init() {}
    
    // MARK: - Authorization
    
    /// Request notification permission (sound only - no alerts or badges)
    func requestAuthorization() async -> Bool {
        do {
            // Request sound permission - we need this for bells to play
            let granted = try await notificationCenter.requestAuthorization(options: [.sound])
            print("🔔 Notification authorization granted: \(granted)")
            return granted
        } catch {
            print("🔔 Notification authorization error: \(error)")
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
        // Clear any pending notifications first (avoids async race conditions).
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        
        print("🔔 Scheduling notifications - duration: \(duration)s, interval: \(intervalMinutes)min")
        
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
    
    /// Schedule the completion bell notification (sound only - no banner)
    private func scheduleCompletionNotification(in seconds: TimeInterval, sound: TimerSettings.BellSound) {
        let content = UNMutableNotificationContent()
        // No title or body = no visible banner
        content.categoryIdentifier = "MEDITATION_COMPLETE"
        
        // Set the custom sound
        if let soundName = SoundManager.shared.notificationSoundFileName(for: sound) {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
            print("🔔 Completion notification sound: \(soundName)")
        } else {
            content.sound = .default
            print("🔔 Completion notification using default sound")
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: completionNotificationId,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("🔔 Error scheduling completion notification: \(error)")
            } else {
                print("🔔 Scheduled completion notification in \(seconds)s")
            }
        }
    }
    
    /// Schedule interval bell notifications (sound only - no banner)
    private func scheduleIntervalNotifications(
        totalDuration: TimeInterval,
        intervalMinutes: Int,
        sound: TimerSettings.BellSound
    ) {
        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        var currentTime = intervalSeconds
        var intervalIndex = 0
        
        print("🔔 Scheduling interval notifications every \(intervalMinutes) min for \(totalDuration)s total")
        
        while currentTime < totalDuration {
            let content = UNMutableNotificationContent()
            // No title or body = no visible banner
            content.categoryIdentifier = "MEDITATION_INTERVAL"
            
            // Set the custom sound
            if let soundName = SoundManager.shared.notificationSoundFileName(for: sound) {
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
                    print("🔔 Error scheduling interval notification \(intervalIndex): \(error)")
                } else {
                    print("🔔 Scheduled interval notification \(intervalIndex) at \(currentTime)s")
                }
            }
            
            currentTime += intervalSeconds
            intervalIndex += 1
        }
        
        print("🔔 Total interval notifications scheduled: \(intervalIndex)")
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
            
            if !meditationIds.isEmpty {
                print("🔔 Cancelling \(meditationIds.count) meditation notifications")
            }
            
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
