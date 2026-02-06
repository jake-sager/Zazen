//
//  SettingsView.swift
//  Zazen
//
//  Created by Jake Sager on 1/7/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var timerSettings: TimerSettings
    var store: MeditationStore

    private let minMaxMinutes: Int = 60
    private let maxMaxMinutes: Int = 360
    private let step: Int = 15

    // Dev debug state for bonsai growth testing
    @State private var debugStreak: Int? = nil
    @State private var growthTimer: Timer? = nil
    @State private var isHoldingGrow = false

    private var isDevBuild: Bool {
        Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true
    }

    private var effectiveStreak: Int {
        min(debugStreak ?? store.currentStreak, 365)
    }

    var body: some View {
        ZStack {
            PaperTextureBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    timerSection
                    bonsaiSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIMER")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.32)
                .foregroundColor(Color.textMuted)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("MAX TIME")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.32)
                        .foregroundColor(Color.textMuted)

                    Spacer()

                    Text(maxTimeLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.textPrimary)
                }

                Slider(
                    value: Binding(
                        get: { Double(clampedMaxTimerMinutes) },
                        set: { newValue in
                            timerSettings.maxTimerMinutes = Int(newValue)
                            timerSettings.save()
                        }
                    ),
                    in: Double(minMaxMinutes)...Double(maxMaxMinutes),
                    step: Double(step)
                )
                .tint(Color.accentPrimary)

                Text("Increase this to allow longer sessions on the timer dial.")
                    .font(.system(size: 12))
                    .foregroundColor(Color.textMuted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .neumorphicCard()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("START DELAY")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.32)
                        .foregroundColor(Color.textMuted)

                    Spacer()

                    Text(delayLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(timerSettings.startDelaySeconds > 0 ? Color.textPrimary : Color.textMuted)
                }

                Slider(
                    value: Binding(
                        get: { Double(timerSettings.startDelaySeconds) },
                        set: {
                            timerSettings.startDelaySeconds = Int($0)
                            timerSettings.save()
                        }
                    ),
                    in: 0...60,
                    step: 5
                )
                .tint(Color.accentPrimary)

                Toggle(isOn: Binding(
                    get: { timerSettings.playStartingBell },
                    set: {
                        timerSettings.playStartingBell = $0
                        timerSettings.save()
                    }
                )) {
                    Text("STARTING BELL")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.32)
                        .foregroundColor(Color.textMuted)
                }
                .tint(Color.accentPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .neumorphicCard()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clampedMaxTimerMinutes: Int {
        min(max(timerSettings.maxTimerMinutes, minMaxMinutes), maxMaxMinutes)
    }

    private var delayLabel: String {
        timerSettings.startDelaySeconds == 0 ? "Off" : "\(timerSettings.startDelaySeconds)s"
    }

    private var maxTimeLabel: String {
        if clampedMaxTimerMinutes >= 60 {
            let h = clampedMaxTimerMinutes / 60
            let m = clampedMaxTimerMinutes % 60
            if m == 0 {
                return "Up to \(h) hr"
            } else {
                return "Up to \(h) hr \(m) min"
            }
        } else {
            return "Up to \(clampedMaxTimerMinutes) min"
        }
    }

    // MARK: - Bonsai Tree

    private var bonsaiSection: some View {
        VStack(spacing: 8) {
            BonsaiTreeView(streakDays: effectiveStreak)
                .frame(maxHeight: 280)

            if effectiveStreak > 0 {
                Text("day \(effectiveStreak)")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.0)
                    .foregroundColor(Color.textMuted.opacity(0.5))
            }

            if isDevBuild {
                Text(isHoldingGrow ? "day \(effectiveStreak)" : "hold to grow")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.8)
                    .foregroundColor(Color.textMuted)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(Color.neumorphicFrame)
                    .clipShape(Capsule())
                    .padding(.top, 4)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in startGrowth() }
                            .onEnded { _ in stopGrowth() }
                    )
            }
        }
    }

    private func startGrowth() {
        guard growthTimer == nil else { return }
        isHoldingGrow = true
        if debugStreak == nil { debugStreak = 0 }
        growthTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
            if let current = debugStreak {
                debugStreak = current >= 365 ? 0 : current + 1
            }
        }
    }

    private func stopGrowth() {
        isHoldingGrow = false
        growthTimer?.invalidate()
        growthTimer = nil
    }
}

#Preview {
    SettingsView(timerSettings: TimerSettings(), store: MeditationStore())
}


