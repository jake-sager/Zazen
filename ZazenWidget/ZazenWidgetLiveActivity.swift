//
//  ZazenWidgetLiveActivity.swift
//  ZazenWidget
//
//  Created by Jake Sager on 1/4/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

// Colors are hardcoded (not from Asset catalog / system dynamic colors) so the
// lock-screen activity has the same warm-paper look regardless of the device's
// light/dark appearance. Using adaptive colors here caused dark mode to flip
// text to white on our near-white background tint, killing contrast.
private extension Color {
    // Lock-screen activity palette — matches the app's warm paper theme.
    static let activityBackground = Color(red: 0.918, green: 0.906, blue: 0.882) // #EAE7E1
    static let activityTextPrimary = Color(red: 0.22, green: 0.21, blue: 0.20)   // #383635
    static let activityTextMuted = Color(red: 0.45, green: 0.43, blue: 0.40)     // #736E66
    static let activityAccent = Color(red: 0.506, green: 0.596, blue: 0.675)     // muted slate #8198AC
    static let activityLeaf = Color(red: 0.506, green: 0.627, blue: 0.537)       // sage #819F89
}

struct ZazenWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationActivityAttributes.self) { context in
            // Use system-driven timer rendering so it keeps updating on the lock screen
            let endTime = context.attributes.startTime.addingTimeInterval(TimeInterval(context.attributes.totalDuration))

            HStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.title)
                    .foregroundColor(.activityLeaf)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Meditating")
                        .font(.caption)
                        .foregroundColor(.activityTextMuted)

                    Text(endTime, style: .timer)
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(.activityTextPrimary)
                }

                Spacer()

                // System-updating progress ring, with *no* current value label.
                // Some iOS versions still render a countdown inside the ring unless we explicitly
                // provide an empty currentValueLabel.
                ProgressView(timerInterval: context.attributes.startTime...endTime, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(.activityAccent)
                .frame(width: 44, height: 44)
            }
            .padding(16)
            .activityBackgroundTint(.activityBackground)
            .activitySystemActionForegroundColor(.activityTextPrimary)

        } dynamicIsland: { context in
            // Dynamic Island always renders on a black pill, so system adaptive
            // colors (.primary / .secondary) work fine here -- they resolve to
            // white / light gray against the dark background.
            let endTime = context.attributes.startTime.addingTimeInterval(TimeInterval(context.attributes.totalDuration))

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.activityLeaf)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("Meditating")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(endTime, style: .timer)
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text("Zazen")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.activityLeaf)
            } compactTrailing: {
                Text(endTime, style: .timer)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.primary)
            } minimal: {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.activityLeaf)
            }
        }
    }
}

#Preview("Live Activity", as: .content, using: MeditationActivityAttributes(totalDuration: 600, startTime: Date())) {
    ZazenWidgetLiveActivity()
} contentStates: {
    MeditationActivityAttributes.ContentState(remainingSeconds: 300, isOvertime: false, timerState: .running)
    MeditationActivityAttributes.ContentState(remainingSeconds: 60, isOvertime: true, timerState: .overtime)
}
