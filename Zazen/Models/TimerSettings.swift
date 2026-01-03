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
    @Published var bellSound: BellSound = .singing
    @Published var intervalMinutes: Int = 0  // 0 means disabled
    @Published var intervalBellSound: BellSound = .singing
    
    private static let saveKey = "timer_settings"
    
    enum BellSound: String, CaseIterable, Identifiable, Codable {
        case singing = "Singing Bowl"
        case tingsha = "Tingsha"
        case woodBlock = "Wood Block"
        case silence = "Silence"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .singing: return "Traditional singing bowl tone"
            case .tingsha: return "Bright Tibetan cymbal"
            case .woodBlock: return "Soft wooden percussion"
            case .silence: return "No sound"
            }
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case hours, minutes, seconds, bellSound, intervalMinutes, intervalBellSound
    }
    
    init() {
        load()
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hours = try container.decode(Int.self, forKey: .hours)
        minutes = try container.decode(Int.self, forKey: .minutes)
        seconds = try container.decode(Int.self, forKey: .seconds)
        bellSound = try container.decode(BellSound.self, forKey: .bellSound)
        intervalMinutes = try container.decode(Int.self, forKey: .intervalMinutes)
        intervalBellSound = try container.decode(BellSound.self, forKey: .intervalBellSound)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hours, forKey: .hours)
        try container.encode(minutes, forKey: .minutes)
        try container.encode(seconds, forKey: .seconds)
        try container.encode(bellSound, forKey: .bellSound)
        try container.encode(intervalMinutes, forKey: .intervalMinutes)
        try container.encode(intervalBellSound, forKey: .intervalBellSound)
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
            self.bellSound = decoded.bellSound
            self.intervalMinutes = decoded.intervalMinutes
            self.intervalBellSound = decoded.intervalBellSound
        }
    }
}
