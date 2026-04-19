//
//  ZazenWidgetLiveActivity.swift
//  ZazenWidget
//
//  Created by Jake Sager on 1/4/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

// Lock-screen activity palette -- hardcoded rather than adaptive system colors
// so we have full control over the warm washi look. The activity runs in a
// separate process, so we can't rely on the app's `.preferredColorScheme`
// propagating here. Instead, the user's choice is passed in via the activity
// attributes (`forcedColorSchemeRaw`), and we fall back to the widget's own
// environment `\.colorScheme` when the user has chosen "System".
private struct ActivityPalette {
    let background: Color
    let textPrimary: Color
    let textMuted: Color
    let accent: Color
    let leaf: Color

    static let light = ActivityPalette(
        background:  Color(red: 0.918, green: 0.906, blue: 0.882), // #EAE7E1
        textPrimary: Color(red: 0.22,  green: 0.21,  blue: 0.20),  // #383635
        textMuted:   Color(red: 0.45,  green: 0.43,  blue: 0.40),  // #736E66
        accent:      Color(red: 0.506, green: 0.596, blue: 0.675), // #8198AC
        leaf:        Color(red: 0.506, green: 0.627, blue: 0.537)  // #819F89
    )

    static let dark = ActivityPalette(
        background:  Color(red: 0.122, green: 0.110, blue: 0.094), // #1F1C18 (warm sumi ink)
        textPrimary: Color(red: 0.918, green: 0.894, blue: 0.839), // #EAE4D6
        textMuted:   Color(red: 0.710, green: 0.678, blue: 0.616), // #B5AD9D
        accent:      Color(red: 0.486, green: 0.533, blue: 0.580), // #7C8894 (muted analogue slate)
        leaf:        Color(red: 0.522, green: 0.600, blue: 0.494)  // #85997E (muted sage)
    )

    /// Resolve the palette for this render:
    /// - A forced "light"/"dark" from the app overrides everything.
    /// - Otherwise fall back to the widget's environment color scheme.
    static func resolved(forcedRaw: String?, environment: ColorScheme) -> ActivityPalette {
        switch forcedRaw {
        case "dark":
            return .dark
        case "light":
            return .light
        default:
            return environment == .dark ? .dark : .light
        }
    }
}

struct ZazenWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationActivityAttributes.self) { context in
            LockScreenView(context: context)

        } dynamicIsland: { context in
            // Dynamic Island always renders on a black pill, so system adaptive
            // colors (.primary / .secondary) work fine here -- they resolve to
            // white / light gray against the dark background.
            let endTime = context.attributes.startTime.addingTimeInterval(TimeInterval(context.attributes.totalDuration))
            let palette = ActivityPalette.resolved(forcedRaw: context.attributes.forcedColorSchemeRaw, environment: .dark)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(palette.leaf)
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
                    .foregroundColor(palette.leaf)
            } compactTrailing: {
                Text(endTime, style: .timer)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.primary)
            } minimal: {
                Image(systemName: "leaf.fill")
                    .foregroundColor(palette.leaf)
            }
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let endTime = context.attributes.startTime.addingTimeInterval(TimeInterval(context.attributes.totalDuration))
        let palette = ActivityPalette.resolved(
            forcedRaw: context.attributes.forcedColorSchemeRaw,
            environment: colorScheme
        )

        HStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.title)
                .foregroundColor(palette.leaf)

            VStack(alignment: .leading, spacing: 4) {
                Text("Meditating")
                    .font(.caption)
                    .foregroundColor(palette.textMuted)

                Text(endTime, style: .timer)
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(palette.textPrimary)
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
            .tint(palette.accent)
            .frame(width: 44, height: 44)
        }
        .padding(16)
        .activityBackgroundTint(palette.background)
        .activitySystemActionForegroundColor(palette.textPrimary)
    }
}

#Preview("Live Activity - Light", as: .content, using: MeditationActivityAttributes(totalDuration: 600, startTime: Date(), forcedColorSchemeRaw: "light")) {
    ZazenWidgetLiveActivity()
} contentStates: {
    MeditationActivityAttributes.ContentState(remainingSeconds: 300, isOvertime: false, timerState: .running)
    MeditationActivityAttributes.ContentState(remainingSeconds: 60, isOvertime: true, timerState: .overtime)
}

#Preview("Live Activity - Dark", as: .content, using: MeditationActivityAttributes(totalDuration: 600, startTime: Date(), forcedColorSchemeRaw: "dark")) {
    ZazenWidgetLiveActivity()
} contentStates: {
    MeditationActivityAttributes.ContentState(remainingSeconds: 300, isOvertime: false, timerState: .running)
    MeditationActivityAttributes.ContentState(remainingSeconds: 60, isOvertime: true, timerState: .overtime)
}
