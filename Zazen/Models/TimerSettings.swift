//
//  TimerSettings.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import Foundation
import Combine

class TimerSettings: ObservableObject, Codable {
    @Published var hours: Int = 0
    @Published var minutes: Int = 5
    @Published var seconds: Int = 0
    /// Maximum selectable timer duration in minutes for the circular dial.
    /// Default is 60 minutes (1 hour).
    @Published var maxTimerMinutes: Int = 60
    @Published var bellSound: BellSound = .bowlB
    @Published var intervalMinutes: Int = 0  // 0 means disabled
    @Published var intervalBellSound: BellSound = .bowlB
    @Published var startDelaySeconds: Int = 0  // 0-60, countdown before meditation begins
    @Published var playStartingBell: Bool = true
    
    private static let saveKey = "timer_settings"
    
    enum BellSound: String, CaseIterable, Identifiable, Codable {
        case bowlA = "I"
        case bowlB = "II"
        case bowlC = "III"
        case silence = "Silence"
        
        var id: String { rawValue }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case hours, minutes, seconds, maxTimerMinutes, bellSound, intervalMinutes, intervalBellSound
        case startDelaySeconds, playStartingBell
    }
    
    init() {
        load()
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hours = try container.decode(Int.self, forKey: .hours)
        minutes = try container.decode(Int.self, forKey: .minutes)
        seconds = try container.decode(Int.self, forKey: .seconds)
        maxTimerMinutes = try container.decodeIfPresent(Int.self, forKey: .maxTimerMinutes) ?? 60
        bellSound = try container.decode(BellSound.self, forKey: .bellSound)
        intervalMinutes = try container.decode(Int.self, forKey: .intervalMinutes)
        intervalBellSound = try container.decode(BellSound.self, forKey: .intervalBellSound)
        startDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .startDelaySeconds) ?? 0
        playStartingBell = try container.decodeIfPresent(Bool.self, forKey: .playStartingBell) ?? true
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hours, forKey: .hours)
        try container.encode(minutes, forKey: .minutes)
        try container.encode(seconds, forKey: .seconds)
        try container.encode(maxTimerMinutes, forKey: .maxTimerMinutes)
        try container.encode(bellSound, forKey: .bellSound)
        try container.encode(intervalMinutes, forKey: .intervalMinutes)
        try container.encode(intervalBellSound, forKey: .intervalBellSound)
        try container.encode(startDelaySeconds, forKey: .startDelaySeconds)
        try container.encode(playStartingBell, forKey: .playStartingBell)
    }
    
    // MARK: - Persistence
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let decoded = try? JSONDecoder().decode(TimerSettings.self, from: data) {
            self.hours = decoded.hours
            self.minutes = decoded.minutes
            self.seconds = decoded.seconds
            self.maxTimerMinutes = max(60, decoded.maxTimerMinutes)
            self.bellSound = decoded.bellSound
            self.intervalMinutes = decoded.intervalMinutes
            self.intervalBellSound = decoded.intervalBellSound
            self.startDelaySeconds = decoded.startDelaySeconds
            self.playStartingBell = decoded.playStartingBell
        }
    }
}
