//
//  ZazenWidgetLiveActivity.swift
//  ZazenWidget
//
//  Created by Jake Sager on 1/4/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

// The Lock Screen surface is system-owned and may be opaque, translucent, light,
// dark, or reduced-luminance depending on OS version and wallpaper. Let semantic
// foreground styles track that surface instead of trying to predict its color.
private extension Color {
    static let activityAccent = Color(red: 0.40, green: 0.47, blue: 0.53)
    static let activityLeaf = Color(red: 0.35, green: 0.50, blue: 0.37)

    // Dynamic Island itself is always black, so explicit warm-light colors are
    // appropriate there.
    static let islandPrimary = Color(red: 0.918, green: 0.894, blue: 0.839)
    static let islandMuted = Color(red: 0.710, green: 0.678, blue: 0.616)
}

struct ZazenWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationActivityAttributes.self) { context in
            LockScreenView(context: context)

        } dynamicIsland: { context in
            // Dynamic Island always renders on a black pill. Keep its content
            // explicit instead of depending on an unrelated color-scheme value.
            let endTime = context.attributes.startTime.addingTimeInterval(TimeInterval(context.attributes.totalDuration))

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Color.activityLeaf)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("Meditating")
                        .font(.caption)
                        .foregroundStyle(Color.islandMuted)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(endTime, style: .timer)
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(Color.islandPrimary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text("Zazen")
                        .font(.caption2)
                        .foregroundStyle(Color.islandMuted)
                }
            } compactLeading: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.activityLeaf)
            } compactTrailing: {
                Text(endTime, style: .timer)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color.islandPrimary)
            } minimal: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.activityLeaf)
            }
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        let endTime = context.attributes.startTime.addingTimeInterval(TimeInterval(context.attributes.totalDuration))

        HStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.title)
                .foregroundStyle(Color.activityLeaf)

            VStack(alignment: .leading, spacing: 4) {
                Text("Meditating")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(endTime, style: .timer)
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Spacer()

            // System-updating progress ring, with *no* current value label.
            // Some iOS versions still render a countdown inside the ring unless
            // we explicitly provide an empty currentValueLabel.
            ProgressView(timerInterval: context.attributes.startTime...endTime, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(Color.activityAccent)
            .frame(width: 44, height: 44)
        }
        .padding(16)
    }
}

#Preview("Live Activity - Light", as: .content, using: MeditationActivityAttributes(totalDuration: 600, startTime: Date())) {
    ZazenWidgetLiveActivity()
} contentStates: {
    MeditationActivityAttributes.ContentState(remainingSeconds: 300, isOvertime: false, timerState: .running)
    MeditationActivityAttributes.ContentState(remainingSeconds: 60, isOvertime: true, timerState: .overtime)
}

#Preview("Live Activity - Dark", as: .content, using: MeditationActivityAttributes(totalDuration: 600, startTime: Date())) {
    ZazenWidgetLiveActivity()
} contentStates: {
    MeditationActivityAttributes.ContentState(remainingSeconds: 300, isOvertime: false, timerState: .running)
    MeditationActivityAttributes.ContentState(remainingSeconds: 60, isOvertime: true, timerState: .overtime)
}
