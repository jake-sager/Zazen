//
//  LiveActivityManager.swift
//  Zazen
//
//  Created by Jake Sager on 1/4/26.
//

import ActivityKit
import Foundation

/// Manages Live Activities for meditation sessions
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private(set) var currentActivity: Activity<MeditationActivityAttributes>?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Start a new Live Activity for a meditation session
    func startActivity(totalDuration: Int) {
        print("🧘 LiveActivityManager: startActivity called with duration \(totalDuration)")
        
        // Check if Live Activities are supported
        let authInfo = ActivityAuthorizationInfo()
        print("🧘 Live Activities enabled: \(authInfo.areActivitiesEnabled)")
        print("🧘 Frequent push enabled: \(authInfo.frequentPushesEnabled)")
        
        guard authInfo.areActivitiesEnabled else {
            print("🧘 ERROR: Live Activities are not enabled - check Settings → Zazen → Live Activities")
            return
        }
        
        // End any existing activity first
        endActivity()
        
        let attributes = MeditationActivityAttributes(
            totalDuration: totalDuration,
            startTime: Date()
        )
        
        let initialState = MeditationActivityAttributes.ContentState(
            remainingSeconds: totalDuration,
            isOvertime: false,
            timerState: .running
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("🧘 SUCCESS: Started Live Activity with ID: \(activity.id)")
        } catch {
            print("🧘 ERROR starting Live Activity: \(error)")
        }
    }
    
    /// Update the Live Activity with new remaining time
    func updateActivity(remainingSeconds: Int, isOvertime: Bool = false) {
        guard let activity = currentActivity else { return }
        
        let state = MeditationActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            isOvertime: isOvertime,
            timerState: isOvertime ? .overtime : .running
        )
        
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: nil)
            )
        }
    }
    
    /// Transition the activity to overtime state
    func transitionToOvertime(overtimeSeconds: Int) {
        guard let activity = currentActivity else { return }
        
        let state = MeditationActivityAttributes.ContentState(
            remainingSeconds: overtimeSeconds,
            isOvertime: true,
            timerState: .overtime
        )
        
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: nil)
            )
        }
    }
    
    /// End the Live Activity
    func endActivity() {
        guard let activity = currentActivity else { return }
        
        let finalState = MeditationActivityAttributes.ContentState(
            remainingSeconds: 0,
            isOvertime: false,
            timerState: .completed
        )
        
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        
        currentActivity = nil
    }
    
    /// Check if Live Activities are available
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
}

