//
//  MeditationActivityAttributes.swift
//  ZazenWidget
//
//  Created by Jake Sager on 1/4/26.
//

import ActivityKit
import Foundation

/// Defines the attributes for the meditation Live Activity
/// NOTE: This file must be kept in sync with the version in the main app
struct MeditationActivityAttributes: ActivityAttributes {
    /// Dynamic state that updates during the activity
    public struct ContentState: Codable, Hashable {
        /// The time remaining in seconds (negative means overtime)
        var remainingSeconds: Int
        
        /// Whether the timer is in overtime mode
        var isOvertime: Bool
        
        /// Timer state for display purposes
        var timerStateRaw: String
        
        var timerState: TimerDisplayState {
            TimerDisplayState(rawValue: timerStateRaw) ?? .running
        }
        
        init(remainingSeconds: Int, isOvertime: Bool = false, timerState: TimerDisplayState = .running) {
            self.remainingSeconds = remainingSeconds
            self.isOvertime = isOvertime
            self.timerStateRaw = timerState.rawValue
        }
    }
    
    /// Timer display states
    enum TimerDisplayState: String, Codable {
        case running
        case overtime
        case completed
    }
    
    /// Static data that doesn't change during the activity
    let totalDuration: Int  // Total meditation duration in seconds
    let startTime: Date
}

