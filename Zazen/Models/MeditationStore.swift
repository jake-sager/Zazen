//
//  MeditationStore.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import Foundation
import SwiftUI

@Observable
class MeditationStore {
    private(set) var sessions: [MeditationSession] = []
    
    private let saveKey = "meditation_sessions"
    
    init() {
        loadSessions()
    }
    
    func addSession(_ session: MeditationSession) {
        sessions.append(session)
        sessions.sort { $0.date < $1.date }
        saveSessions()
    }
    
    func addSession(date: Date, durationMinutes: Int) {
        let session = MeditationSession(
            date: date,
            durationSeconds: durationMinutes * 60
        )
        addSession(session)
    }
    
    func deleteSession(_ session: MeditationSession) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }
    
    // MARK: - Computed Properties
    
    var totalMinutes: Int {
        Int(sessions.reduce(0) { $0 + $1.durationMinutes })
    }
    
    var totalHours: Double {
        Double(totalMinutes) / 60.0
    }
    
    var currentStreak: Int {
        guard !sessions.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get unique dates (normalized to start of day)
        let uniqueDates = Set(sessions.map { calendar.startOfDay(for: $0.date) })
            .sorted(by: >)
        
        guard let mostRecent = uniqueDates.first else { return 0 }
        
        // Check if most recent is today or yesterday
        let daysSinceMostRecent = calendar.dateComponents([.day], from: mostRecent, to: today).day ?? 0
        if daysSinceMostRecent > 1 {
            return 0 // Streak broken
        }
        
        var streak = 0
        var expectedDate = daysSinceMostRecent == 0 ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        
        for date in uniqueDates {
            if calendar.isDate(date, inSameDayAs: expectedDate) {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if date < expectedDate {
                break // Gap in streak
            }
        }
        
        return streak
    }
    
    var sessionsLast7Days: [(date: Date, minutes: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let minutes = sessions
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.durationMinutes }
            return (date: date, minutes: minutes)
        }
    }
    
    var sessionsLast30Days: [(date: Date, minutes: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<30).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let minutes = sessions
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.durationMinutes }
            return (date: date, minutes: minutes)
        }
    }
    
    var sessionsAllTime: [(date: Date, minutes: Double)] {
        guard !sessions.isEmpty else { return [] }
        
        let calendar = Calendar.current
        
        // Group sessions by day
        var dailyTotals: [Date: Double] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            dailyTotals[day, default: 0] += session.durationMinutes
        }
        
        // Sort by date
        return dailyTotals
            .map { (date: $0.key, minutes: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    // MARK: - Persistence
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([MeditationSession].self, from: data) {
            sessions = decoded.sorted { $0.date < $1.date }
        }
    }
}

// Make MeditationSession Equatable for comparison
extension MeditationSession: Equatable {
    static func == (lhs: MeditationSession, rhs: MeditationSession) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date && lhs.durationSeconds == rhs.durationSeconds
    }
}
