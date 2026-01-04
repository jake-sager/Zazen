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
            // Lock screen/banner UI - simplified for debugging
            HStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.title)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.isOvertime ? "Overtime" : "Meditating")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(context.state.remainingSeconds, isOvertime: context.state.isOvertime))
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                }
                
                Spacer()
                
                if !context.state.isOvertime {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        
                        Circle()
                            .trim(from: 0, to: progress(context: context))
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 44, height: 44)
                }
            }
            .padding(16)
            .activityBackgroundTint(Color(white: 0.95))
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.isOvertime ? "Overtime" : "Meditating")
                        .font(.caption)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(formatTime(context.state.remainingSeconds, isOvertime: context.state.isOvertime))
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
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
                Text(formatTimeShort(context.state.remainingSeconds, isOvertime: context.state.isOvertime))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
            } minimal: {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
            }
        }
    }
    
    private func progress(context: ActivityViewContext<MeditationActivityAttributes>) -> Double {
        let total = Double(context.attributes.totalDuration)
        let remaining = Double(context.state.remainingSeconds)
        guard total > 0 else { return 0 }
        return max(0, min(1, (total - remaining) / total))
    }
    
    private func formatTime(_ totalSeconds: Int, isOvertime: Bool) -> String {
        let absSeconds = abs(totalSeconds)
        let m = absSeconds / 60
        let s = absSeconds % 60
        let prefix = isOvertime ? "+" : ""
        return "\(prefix)\(String(format: "%02d:%02d", m, s))"
    }
    
    private func formatTimeShort(_ totalSeconds: Int, isOvertime: Bool) -> String {
        let absSeconds = abs(totalSeconds)
        let m = absSeconds / 60
        let s = absSeconds % 60
        let prefix = isOvertime ? "+" : ""
        return "\(prefix)\(m):\(String(format: "%02d", s))"
    }
}

#Preview("Live Activity", as: .content, using: MeditationActivityAttributes(totalDuration: 600, startTime: Date())) {
    ZazenWidgetLiveActivity()
} contentStates: {
    MeditationActivityAttributes.ContentState(remainingSeconds: 300, isOvertime: false, timerState: .running)
    MeditationActivityAttributes.ContentState(remainingSeconds: 60, isOvertime: true, timerState: .overtime)
}

