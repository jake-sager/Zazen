//
//  StatsView.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import SwiftUI
import Charts

struct StatsView: View {
    var store: MeditationStore
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingAddSession = false
    
    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case allTime = "All Time"
    }
    
    var body: some View {
        ZStack {
            PaperTextureBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Streak card
                    streakCard
                    
                    // Chart card
                    chartCard
                    
                    // Total stats card
                    totalStatsCard
                    
                    // Add session button
                    addSessionButton
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .sheet(isPresented: $showingAddSession) {
            AddSessionView(store: store)
        }
    }
    
    // MARK: - Streak Card
    
    private var streakCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(white: 0.65))
                
                Text("\(store.currentStreak)")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(Color.textPrimary)
            }
            
            Text("DAY STREAK")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.32)
                .foregroundColor(Color.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .neumorphicCard()
    }
    
    // MARK: - Chart Card
    
    private var chartCard: some View {
        VStack(spacing: 20) {
            // Time range picker
            HStack(spacing: 0) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTimeRange = range
                        }
                    }) {
                        Text(range.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedTimeRange == range ? Color.textPrimary : Color.textMuted)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                selectedTimeRange == range ?
                                    Color.neumorphicCard : Color.clear
                            )
                            .clipShape(Capsule())
                            .shadow(
                                color: selectedTimeRange == range ? Color.shadowDark.opacity(0.3) : Color.clear,
                                radius: 4, x: 2, y: 2
                            )
                            .shadow(
                                color: selectedTimeRange == range ? Color.shadowLight.opacity(0.7) : Color.clear,
                                radius: 4, x: -2, y: -2
                            )
                    }
                }
            }
            .padding(4)
            .background(Color.neumorphicFrame)
            .clipShape(Capsule())
            
            // Chart
            chartContent
        }
        .padding(24)
        .neumorphicCard()
    }
    
    private var chartData: [(date: Date, minutes: Double)] {
        switch selectedTimeRange {
        case .week:
            return store.sessionsLast7Days
        case .month:
            return store.sessionsLast30Days
        case .allTime:
            return store.sessionsAllTime
        }
    }
    
    @ViewBuilder
    private var chartContent: some View {
        if chartData.isEmpty || chartData.allSatisfy({ $0.minutes == 0 }) {
            // Empty state
            VStack(spacing: 12) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 40))
                    .foregroundColor(Color.textMuted.opacity(0.5))
                
                Text("No sessions yet")
                    .font(.system(size: 14))
                    .foregroundColor(Color.textMuted)
            }
            .frame(height: 200)
        } else {
            let maxMinutes = chartData.map(\.minutes).max() ?? 10
            let yMax = max(10, ceil(maxMinutes / 10) * 10) // Round up to nearest 10, minimum 10
            
            Chart(chartData, id: \.date) { item in
                BarMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.chartBar, Color.chartBarSecondary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(3)
            }
            .chartYScale(domain: 0...yMax)
            .chartXAxis {
                if selectedTimeRange == .week {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.weekday(.abbreviated))
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.textMuted)
                            }
                        }
                    }
                } else if selectedTimeRange == .month {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.textMuted)
                            }
                        }
                    }
                } else {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.textMuted)
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.textMuted.opacity(0.3))
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            Text("\(Int(minutes))m")
                                .font(.system(size: 10))
                                .foregroundColor(Color.textMuted)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
    }
    
    // MARK: - Total Stats Card
    
    private var totalStatsCard: some View {
        HStack(spacing: 0) {
            // Total sessions
            VStack(spacing: 8) {
                Text("\(store.sessions.count)")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color.textPrimary)
                
                Text("SESSIONS")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundColor(Color.textMuted)
            }
            .frame(maxWidth: .infinity)
            
            // Divider
            Rectangle()
                .fill(Color.textMuted.opacity(0.2))
                .frame(width: 1, height: 50)
            
            // Total time - show hours if >= 60 min
            VStack(spacing: 8) {
                if store.totalMinutes >= 60 {
                    Text(String(format: "%.1f", store.totalHours))
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(Color.textPrimary)
                    
                    Text("HOURS")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.2)
                        .foregroundColor(Color.textMuted)
                } else {
                    Text("\(store.totalMinutes)")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(Color.textPrimary)
                    
                    Text("MINUTES")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.2)
                        .foregroundColor(Color.textMuted)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 28)
        .neumorphicCard()
    }
    
    // MARK: - Add Session Button
    
    private var addSessionButton: some View {
        Button(action: {
            showingAddSession = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                Text("Add Past Session")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Color.textMuted)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .neumorphicCard()
    }
}

// MARK: - Add Session View

struct AddSessionView: View {
    var store: MeditationStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var date = Date()
    @State private var hours: Int = 0
    @State private var minutes: Int = 10
    
    var body: some View {
        NavigationStack {
            ZStack {
                PaperTextureBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Date picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DATE")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1.32)
                            .foregroundColor(Color.textMuted)
                        
                        DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .neumorphicCard()
                    
                    // Duration picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DURATION")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1.32)
                            .foregroundColor(Color.textMuted)
                        
                        HStack(spacing: 20) {
                            // Hours
                            HStack(spacing: 8) {
                                Picker("Hours", selection: $hours) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text("\(h)").tag(h)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60, height: 120)
                                .clipped()
                                
                                Text("hr")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.textMuted)
                            }
                            
                            // Minutes
                            HStack(spacing: 8) {
                                Picker("Minutes", selection: $minutes) {
                                    ForEach(0..<60, id: \.self) { m in
                                        Text("\(m)").tag(m)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60, height: 120)
                                .clipped()
                                
                                Text("min")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.textMuted)
                            }
                        }
                    }
                    .padding(20)
                    .neumorphicCard()
                    
                    Spacer()
                    
                    // Save button
                    Button(action: saveSession) {
                        Text("SAVE")
                    }
                    .buttonStyle(NeumorphicButtonStyle())
                    .disabled(hours == 0 && minutes == 0)
                    .opacity(hours == 0 && minutes == 0 ? 0.35 : 1)
                }
                .padding(24)
            }
            .navigationTitle("Add Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.textMuted)
                }
            }
        }
    }
    
    private func saveSession() {
        let totalSeconds = hours * 3600 + minutes * 60
        let session = MeditationSession(date: date, durationSeconds: totalSeconds)
        store.addSession(session)
        dismiss()
    }
}

#Preview {
    StatsView(store: MeditationStore())
}
