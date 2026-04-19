//
//  NeumorphicStyle.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import SwiftUI
import UIKit

// MARK: - Color Theme (Warm, washi paper-inspired palette)
//
// Every named color is backed by a dynamic `UIColor` that resolves to a
// light or dark variant depending on the current trait collection. SwiftUI's
// `.preferredColorScheme(...)` drives that trait collection, so the user's
// appearance preference (System / Light / Dark) propagates automatically.
//
// The dark palette is intentionally a warm sumi-ink rather than a flat pure
// black -- the goal is that the washi paper feel carries over.

private func dyn(
    _ lightHex: UInt32,
    _ darkHex: UInt32,
    lightAlpha: CGFloat = 1.0,
    darkAlpha: CGFloat = 1.0
) -> Color {
    Color(UIColor { trait in
        let hex = trait.userInterfaceStyle == .dark ? darkHex : lightHex
        let alpha = trait.userInterfaceStyle == .dark ? darkAlpha : lightAlpha
        return UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    })
}

extension Color {
    // Backgrounds -- warm washi paper tones (light) / warm sumi ink (dark)
    static let neumorphicBackground = dyn(0xEAE7E1, 0x1F1C18)
    static let neumorphicCard       = dyn(0xF2F0EC, 0x2A2621)
    static let neumorphicFrame      = dyn(0xE0DDD7, 0x17140F)

    // Shadows -- warm tinted. Call sites already bake in their own opacity
    // (e.g. `Color.shadowLight.opacity(0.8)`), so we tune the base alpha per
    // mode: in dark mode the "highlight" is heavily toned down so cards don't
    // ring with a warm halo against the ink background.
    static let shadowDark  = dyn(0xC8C4BC, 0x050403, lightAlpha: 1.0, darkAlpha: 0.55)
    static let shadowLight = dyn(0xFCFBF9, 0x2A2620, lightAlpha: 1.0, darkAlpha: 0.18)

    // Text -- warm grays (light) / warm creams (dark)
    static let textPrimary   = dyn(0x383635, 0xEAE4D6)
    static let textSecondary = dyn(0x736E66, 0xB5AD9D)
    static let textMuted     = dyn(0x99948A, 0x7E786C)

    // Accent -- muted slate. In dark mode we pull the saturation *down*, not
    // up, so it reads as analogue/aged rather than electric. Slight warm cast
    // keeps it sympathetic to the sumi-ink background.
    static let accentPrimary   = dyn(0x8198AC, 0x7C8894)
    static let accentSecondary = dyn(0x98AABA, 0x8E98A1)

    // Button -- mirrors the accent.
    static let buttonBackground      = dyn(0x8198AC, 0x7C8894)
    static let buttonBackgroundHover = dyn(0x738AA0, 0x6B7682)
    static let buttonText            = Color.white

    // Chart colors
    static let chartBar          = dyn(0x8198AC, 0x7C8894)
    static let chartBarSecondary = dyn(0x98AABA, 0x8E98A1)

    // Success -- muted sage. Dark variant is also pulled back from saturated.
    static let success = dyn(0x819F89, 0x85997E)

    // Borders
    static let borderPrimary   = dyn(0xE0DDD7, 0x17140F)
    static let borderSecondary = dyn(0xEAE7E1, 0x1F1C18)
}

// MARK: - Paper Texture Background

struct PaperTextureBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.neumorphicBackground

            // In light mode we lay subtle dark specks/fibers over warm paper.
            // In dark mode we invert to warm highlights so the texture still
            // reads as paper grain rather than washing out against the ink.
            let isDark = colorScheme == .dark
            let grainColor: Color = isDark ? .white : .black
            let grainOpacityRange: ClosedRange<Double> = isDark ? 0.015...0.04 : 0.02...0.06
            let fiberOpacityRange: ClosedRange<Double> = isDark ? 0.01...0.025 : 0.015...0.035

            Canvas { context, size in
                for _ in 0..<Int(size.width * size.height * 0.003) {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let opacity = Double.random(in: grainOpacityRange)
                    let radius = CGFloat.random(in: 0.5...1.5)

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(grainColor.opacity(opacity))
                    )
                }

                for _ in 0..<Int(size.width * 0.15) {
                    let startX = CGFloat.random(in: 0..<size.width)
                    let startY = CGFloat.random(in: 0..<size.height)
                    let length = CGFloat.random(in: 8...25)
                    let angle = CGFloat.random(in: 0..<(.pi * 2))

                    let endX = startX + cos(angle) * length
                    let endY = startY + sin(angle) * length

                    var path = Path()
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))

                    context.stroke(
                        path,
                        with: .color(grainColor.opacity(Double.random(in: fiberOpacityRange))),
                        lineWidth: CGFloat.random(in: 0.3...0.8)
                    )
                }
            }
        }
    }
}

// MARK: - Neumorphic Card Modifier

struct NeumorphicCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.neumorphicCard)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.shadowDark.opacity(0.5), radius: 10, x: 5, y: 5)
            .shadow(color: Color.shadowLight.opacity(0.8), radius: 10, x: -5, y: -5)
    }
}

extension View {
    func neumorphicCard() -> some View {
        modifier(NeumorphicCard())
    }
}

// MARK: - Neumorphic Inset Modifier

struct NeumorphicInset: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.neumorphicFrame)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.shadowDark.opacity(0.3), lineWidth: 1)
                    .shadow(color: Color.shadowDark, radius: 4, x: 2, y: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.shadowLight.opacity(0.5), lineWidth: 1)
                    .shadow(color: Color.shadowLight, radius: 4, x: -2, y: -2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
    }
}

extension View {
    func neumorphicInset() -> some View {
        modifier(NeumorphicInset())
    }
}

// MARK: - Primary Button Style

struct NeumorphicButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    var horizontalPadding: CGFloat = 64
    var verticalPadding: CGFloat = 16
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .default))
            .tracking(2.4)
            .foregroundColor(Color.buttonText)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                ZStack {
                    Color.buttonBackground
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .clipShape(Capsule())
            .shadow(color: Color.shadowDark.opacity(0.5), radius: 8, x: 0, y: 4)
            .shadow(color: Color.shadowDark.opacity(0.3), radius: 3, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Secondary/Destructive Pill Button (for minimal in-session actions)

struct NeumorphicPillButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
    }
    
    var kind: Kind = .secondary
    var horizontalPadding: CGFloat = 18
    var verticalPadding: CGFloat = 14
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .default))
            .tracking(2.0)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    backgroundColor
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .clipShape(Capsule())
            .shadow(color: Color.shadowDark.opacity(0.35), radius: 8, x: 0, y: 4)
            .shadow(color: Color.shadowLight.opacity(0.6), radius: 6, x: 0, y: -2)
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        switch kind {
        case .primary:
            return Color.buttonText
        case .secondary:
            return Color.textPrimary
        case .destructive:
            return Color.red.opacity(0.95)
        }
    }
    
    private var backgroundColor: Color {
        switch kind {
        case .primary:
            return Color.buttonBackground
        case .secondary, .destructive:
            return Color.neumorphicCard
        }
    }
    
    private var borderColor: Color {
        switch kind {
        case .primary:
            return Color.white.opacity(0.12)
        case .secondary:
            return Color.borderPrimary.opacity(0.9)
        case .destructive:
            return Color.red.opacity(0.28)
        }
    }
    
    private var gradientColors: [Color] {
        switch kind {
        case .primary:
            return [
                Color.white.opacity(0.12),
                Color.clear,
                Color.black.opacity(0.08)
            ]
        case .secondary, .destructive:
            return [
                Color.white.opacity(0.10),
                Color.clear,
                Color.black.opacity(0.05)
            ]
        }
    }
}
