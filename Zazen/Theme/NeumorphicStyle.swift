//
//  NeumorphicStyle.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import SwiftUI

// MARK: - Color Theme (Warm, washi paper-inspired palette)

extension Color {
    // Backgrounds - warm washi paper tones
    static let neumorphicBackground = Color(red: 0.918, green: 0.906, blue: 0.882) // Warm paper #EAE7E1
    static let neumorphicCard = Color(red: 0.949, green: 0.941, blue: 0.925)       // Lighter paper #F2F0EC
    static let neumorphicFrame = Color(red: 0.878, green: 0.867, blue: 0.843)      // Deeper paper #E0DDD7
    
    // Shadows - warm tinted
    static let shadowDark = Color(red: 0.784, green: 0.769, blue: 0.737)           // Warm shadow #C8C4BC
    static let shadowLight = Color(red: 0.988, green: 0.984, blue: 0.976)          // Warm highlight
    
    // Text - warm grays
    static let textPrimary = Color(red: 0.22, green: 0.21, blue: 0.20)             // Warm charcoal #383635
    static let textSecondary = Color(red: 0.45, green: 0.43, blue: 0.40)           // Warm medium #736E66
    static let textMuted = Color(red: 0.60, green: 0.58, blue: 0.54)               // Warm light #99948A
    
    // Accent - muted slate blue (pastel/matte)
    static let accentPrimary = Color(red: 0.506, green: 0.596, blue: 0.675)        // Muted slate #8198AC
    static let accentSecondary = Color(red: 0.596, green: 0.667, blue: 0.729)      // Lighter slate #98AABA
    
    // Button - using muted slate blue
    static let buttonBackground = Color(red: 0.506, green: 0.596, blue: 0.675)     // #8198AC
    static let buttonBackgroundHover = Color(red: 0.45, green: 0.54, blue: 0.62)   // Darker slate
    static let buttonText = Color.white
    
    // Chart colors - muted blues
    static let chartBar = Color(red: 0.506, green: 0.596, blue: 0.675)             // #8198AC
    static let chartBarSecondary = Color(red: 0.596, green: 0.667, blue: 0.729)    // #98AABA
    
    // Success/positive - muted sage green
    static let success = Color(red: 0.506, green: 0.627, blue: 0.537)              // #819F89
    
    // Borders
    static let borderPrimary = Color(red: 0.878, green: 0.867, blue: 0.843)        // #E0DDD7
    static let borderSecondary = Color(red: 0.918, green: 0.906, blue: 0.882)      // #EAE7E1
}

// MARK: - Paper Texture Background

struct PaperTextureBackground: View {
    var body: some View {
        ZStack {
            Color.neumorphicBackground
            
            // Subtle noise texture
            Canvas { context, size in
                // Create subtle paper grain effect
                for _ in 0..<Int(size.width * size.height * 0.003) {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let opacity = Double.random(in: 0.02...0.06)
                    let radius = CGFloat.random(in: 0.5...1.5)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(Color.black.opacity(opacity))
                    )
                }
                
                // Add subtle fiber lines
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
                        with: .color(Color.black.opacity(Double.random(in: 0.015...0.035))),
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
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .default))
            .tracking(2.4)
            .foregroundColor(Color.buttonText)
            .padding(.horizontal, 64)
            .padding(.vertical, 16)
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
