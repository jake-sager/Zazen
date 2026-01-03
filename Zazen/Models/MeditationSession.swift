//
//  MeditationSession.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import Foundation

struct MeditationSession: Codable, Identifiable {
    let id: UUID
    let date: Date
    let durationSeconds: Int
    
    init(id: UUID = UUID(), date: Date = Date(), durationSeconds: Int) {
        self.id = id
        self.date = date
        self.durationSeconds = durationSeconds
    }
    
    var durationMinutes: Double {
        Double(durationSeconds) / 60.0
    }
}

