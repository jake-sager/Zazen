//
//  ZazenWidgetLiveActivity.swift
//  ZazenWidget
//
//  Created by Jake Sager on 1/4/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ZazenWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationActivityAttributes.self) { context in
            // Use system-driven timer rendering so it keeps updating on the lock screen
            let endTime = context.attributes.startTime.addingTimeInterval(TimeInterval(context.attributes.totalDuration))

            HStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.title)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Meditating")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(endTime, style: .timer)
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .monospacedDigit()
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
                .tint(.green)
                .frame(width: 44, height: 44)
            }
            .padding(16)
            .activityBackgroundTint(Color(white: 0.95))
            
        } dynamicIsland: { context in
            let endTime = context.attributes.startTime.addingTimeInterval(TimeInterval(context.attributes.totalDuration))

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Meditating")
                        .font(.caption)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(endTime, style: .timer)
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Zazen")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
            } compactTrailing: {
                Text(endTime, style: .timer)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
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
