//
//  SettingsView.swift
//  Zazen
//
//  Created by Jake Sager on 1/7/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var timerSettings: TimerSettings

    private let minMaxMinutes: Int = 60
    private let maxMaxMinutes: Int = 360
    private let step: Int = 15

    var body: some View {
        ZStack {
            PaperTextureBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    timerSection
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clampedMaxTimerMinutes: Int {
        min(max(timerSettings.maxTimerMinutes, minMaxMinutes), maxMaxMinutes)
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
}

#Preview {
    SettingsView(timerSettings: TimerSettings())
}


