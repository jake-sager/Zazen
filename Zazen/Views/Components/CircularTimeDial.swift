//
//  CircularTimeDial.swift
//  Zazen
//
//  Created by Jake Sager on 1/6/26.
//

import SwiftUI
import UIKit

/// A single circular dial for selecting a duration (in minutes) with a snap-to-minute feel.
struct CircularTimeDial: View {
    @Binding var totalMinutes: Int
    let maxMinutes: Int

    /// Called when the dial snaps to a new minute value (user-driven).
    var onSnap: ((Int) -> Void)?
    /// Called when the user starts/stops interacting with the dial.
    var onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging: Bool = false
    @State private var lastSnappedMinutes: Int?

    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)

    private var clampedMaxMinutes: Int { max(1, maxMinutes) }

    private var clampedMinutes: Int {
        min(max(totalMinutes, 0), clampedMaxMinutes)
    }

    private var progress: Double {
        Double(clampedMinutes) / Double(clampedMaxMinutes)
    }

    private var formattedTime: String {
        let hours = clampedMinutes / 60
        let minutes = clampedMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(20, side * 0.07)
            let radius = side / 2 - lineWidth / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let handleRadius = radius
            let handleHeight = lineWidth
            let handleWidth = max(handleHeight * 2.0, side * 0.14)
            let ring = Circle().inset(by: lineWidth / 2)
            let timeFontSize = max(38, side * 0.18)

            ZStack {
                // Base ring
                ring
                    .stroke(
                        Color.shadowDark.opacity(0.35),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .shadow(color: Color.shadowLight.opacity(0.7), radius: 10, x: -4, y: -4)
                    .shadow(color: Color.shadowDark.opacity(0.25), radius: 10, x: 4, y: 4)

                // Accent ring (progress)
                ring
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        LinearGradient(
                            colors: [Color.accentSecondary.opacity(0.95), Color.accentPrimary.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center time
                VStack(spacing: max(8, timeFontSize * 0.12)) {
                    TabularTimerText(text: formattedTime, fontSize: timeFontSize)

                    unitsRow(timeFontSize: timeFontSize)
                }

                // Handle
                DialHandle(height: handleHeight)
                    .frame(width: handleWidth, height: handleHeight)
                    .rotationEffect(.radians(handleRotation(progress: progress)))
                    .position(handlePosition(center: center, radius: handleRadius, progress: progress))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            lastSnappedMinutes = clampedMinutes
                            impactGenerator.prepare()
                            onEditingChanged?(true)
                        }

                        let snapped = snapMinutes(for: value.location, in: proxy.size)
                        guard snapped != totalMinutes else { return }
                        totalMinutes = snapped
                        tickIfNeeded(snapped)
                    }
                    .onEnded { _ in
                        isDragging = false
                        impactGenerator.prepare()
                        onEditingChanged?(false)
                    }
            )
            .onAppear {
                lastSnappedMinutes = clampedMinutes
                impactGenerator.prepare()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func tickIfNeeded(_ minutes: Int) {
        guard isDragging else { return }
        guard lastSnappedMinutes != minutes else { return }
        lastSnappedMinutes = minutes

        impactGenerator.impactOccurred(intensity: 0.6)
        SoundManager.shared.playTickSound()
        onSnap?(minutes)
    }

    private func handlePosition(center: CGPoint, radius: CGFloat, progress: Double) -> CGPoint {
        let angle = (progress * 2 * Double.pi) - (Double.pi / 2)
        let x = center.x + radius * CGFloat(Darwin.cos(angle))
        let y = center.y + radius * CGFloat(Darwin.sin(angle))
        return CGPoint(x: x, y: y)
    }

    private func handleRotation(progress: Double) -> Double {
        // Tangential orientation: at 12 o'clock the handle is horizontal, at 3 o'clock it's vertical.
        let angle = (progress * 2 * Double.pi) - (Double.pi / 2)
        return angle + (Double.pi / 2)
    }

    private func unitsRow(timeFontSize: CGFloat) -> some View {
        // Match TabularTimerText's fixed widths so labels align under HH and MM groups.
        let digitWidth = timeFontSize * 0.62
        let colonWidth = timeFontSize * 0.35

        return HStack(spacing: 0) {
            Text("H")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.32)
                .foregroundColor(Color.textMuted)
                .frame(width: digitWidth * 2, alignment: .center)

            Color.clear
                .frame(width: colonWidth, height: 1)

            Text("M")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.32)
                .foregroundColor(Color.textMuted)
                .frame(width: digitWidth * 2, alignment: .center)
        }
    }

    private func snapMinutes(for location: CGPoint, in size: CGSize) -> Int {
        guard clampedMaxMinutes > 0 else { return 0 }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        let radians = atan2(dy, dx)
        var degrees = radians * 180 / .pi // 0 at 3 o'clock, CCW positive
        if degrees < 0 { degrees += 360 } // 0...360

        // Convert to 0 at 12 o'clock, increasing clockwise.
        let degreesFromTop = (degrees + 90).truncatingRemainder(dividingBy: 360)
        let fraction = degreesFromTop / 360

        let raw = fraction * Double(clampedMaxMinutes)
        let snapped = Int(round(raw))
        return min(max(snapped, 0), clampedMaxMinutes)
    }
}

private struct DialHandle: View {
    let height: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.neumorphicCard)
                .overlay(
                    Capsule()
                        .stroke(Color.shadowDark.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.shadowDark.opacity(0.22), radius: 6, x: 3, y: 3)
                .shadow(color: Color.shadowLight.opacity(0.80), radius: 6, x: -3, y: -3)

            let markWidth = max(12, height * 0.58)
            let markHeight = max(2, height * 0.10)
            let spacing = max(3, height * 0.18)

            VStack(spacing: spacing) {
                Capsule()
                    .fill(Color.textMuted.opacity(0.55))
                    .frame(width: markWidth, height: markHeight)
                Capsule()
                    .fill(Color.textMuted.opacity(0.55))
                    .frame(width: markWidth, height: markHeight)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.neumorphicBackground.ignoresSafeArea()
        CircularTimeDial(totalMinutes: .constant(11), maxMinutes: 120)
            .padding(24)
    }
}


