//
//  TimerDialSettingsSheet.swift
//  Zazen
//
//  Created by Jake Sager on 1/6/26.
//

import SwiftUI

@available(*, deprecated, message: "Moved into the Settings tab.")
struct TimerDialSettingsSheet: View {
    @ObservedObject var settings: TimerSettings
    @Environment(\.dismiss) private var dismiss

    private let minMaxMinutes: Int = 60
    private let maxMaxMinutes: Int = 360
    private let step: Int = 15

    var body: some View {
        NavigationStack {
            ZStack {
                PaperTextureBackground()
                    .ignoresSafeArea()

                VStack(spacing: 24) {
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
                                    settings.maxTimerMinutes = Int(newValue)
                                    settings.save()
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

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.textMuted)
                }
            }
        }
    }

    private var clampedMaxTimerMinutes: Int {
        min(max(settings.maxTimerMinutes, minMaxMinutes), maxMaxMinutes)
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
    TimerDialSettingsSheet(settings: TimerSettings())
}


