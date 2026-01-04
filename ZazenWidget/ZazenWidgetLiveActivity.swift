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
            // Lock screen/banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(Color(red: 0.45, green: 0.55, blue: 0.45))
                        .font(.title2)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.isOvertime ? "Overtime" : "Meditating")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(formatTimeWithSign(context.state.remainingSeconds, isOvertime: context.state.isOvertime))
                            .font(.system(size: 32, weight: .medium, design: .monospaced))
                            .foregroundColor(context.state.isOvertime ? Color(red: 0.45, green: 0.55, blue: 0.45) : .primary)
                        
                        if !context.state.isOvertime {
                            ProgressView(value: progress(for: context))
                                .tint(Color(red: 0.45, green: 0.55, blue: 0.45))
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Zazen")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: "leaf.fill")
                    .foregroundColor(Color(red: 0.45, green: 0.55, blue: 0.45))
            } compactTrailing: {
                Text(formatTimeCompact(context.state.remainingSeconds, isOvertime: context.state.isOvertime))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(context.state.isOvertime ? Color(red: 0.45, green: 0.55, blue: 0.45) : .primary)
            } minimal: {
                Image(systemName: "leaf.fill")
                    .foregroundColor(Color(red: 0.45, green: 0.55, blue: 0.45))
            }
        }
    }
    
    private func progress(for context: ActivityViewContext<MeditationActivityAttributes>) -> Double {
        let total = Double(context.attributes.totalDuration)
        let remaining = Double(context.state.remainingSeconds)
        guard total > 0 else { return 0 }
        return max(0, min(1, (total - remaining) / total))
    }
    
    private func formatTimeWithSign(_ totalSeconds: Int, isOvertime: Bool) -> String {
        let absSeconds = abs(totalSeconds)
        let h = absSeconds / 3600
        let m = (absSeconds % 3600) / 60
        let s = absSeconds % 60
        
        let prefix = isOvertime ? "+" : ""
        
        if h > 0 {
            return "\(prefix)\(String(format: "%d:%02d:%02d", h, m, s))"
        } else {
            return "\(prefix)\(String(format: "%d:%02d", m, s))"
        }
    }
    
    private func formatTimeCompact(_ totalSeconds: Int, isOvertime: Bool) -> String {
        let absSeconds = abs(totalSeconds)
        let m = absSeconds / 60
        let s = absSeconds % 60
        
        let prefix = isOvertime ? "+" : ""
        return "\(prefix)\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Lock Screen View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>
    
    // Theme colors matching the app
    private let accentColor = Color(red: 0.45, green: 0.55, blue: 0.45)
    private let backgroundColor = Color(red: 0.94, green: 0.93, blue: 0.90)
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - icon
            Image(systemName: "leaf.fill")
                .font(.title)
                .foregroundColor(accentColor)
            
            // Center - timer display
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.isOvertime ? "Overtime" : "Meditating")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatTime(context.state.remainingSeconds, isOvertime: context.state.isOvertime))
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundColor(context.state.isOvertime ? accentColor : .primary)
            }
            
            Spacer()
            
            // Right side - progress ring (only when not in overtime)
            if !context.state.isOvertime {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 44, height: 44)
            }
        }
        .padding(16)
        .activityBackgroundTint(backgroundColor.opacity(0.95))
    }
    
    private var progress: Double {
        let total = Double(context.attributes.totalDuration)
        let remaining = Double(context.state.remainingSeconds)
        guard total > 0 else { return 0 }
        return max(0, min(1, (total - remaining) / total))
    }
    
    private func formatTime(_ totalSeconds: Int, isOvertime: Bool) -> String {
        let absSeconds = abs(totalSeconds)
        let h = absSeconds / 3600
        let m = (absSeconds % 3600) / 60
        let s = absSeconds % 60
        
        let prefix = isOvertime ? "+" : ""
        
        if h > 0 {
            return "\(prefix)\(String(format: "%02d:%02d:%02d", h, m, s))"
        } else {
            return "\(prefix)\(String(format: "%02d:%02d", m, s))"
        }
    }
}

#Preview("Live Activity", as: .content, using: MeditationActivityAttributes(totalDuration: 600, startTime: Date())) {
    ZazenWidgetLiveActivity()
} contentStates: {
    MeditationActivityAttributes.ContentState(remainingSeconds: 300, isOvertime: false, timerState: .running)
    MeditationActivityAttributes.ContentState(remainingSeconds: 60, isOvertime: true, timerState: .overtime)
}

