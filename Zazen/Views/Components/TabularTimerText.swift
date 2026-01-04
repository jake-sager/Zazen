//
//  TabularTimerText.swift
//  Zazen
//
//  Renders a timer string with each character in a fixed-width cell,
//  eliminating horizontal jitter when digits change (even with proportional fonts like Playfair).
//

import SwiftUI
import UIKit

struct TabularTimerText: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    
    init(text: String, fontSize: CGFloat, textColor: Color = .textPrimary) {
        self.text = text
        self.fontSize = fontSize
        self.textColor = textColor
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(timerFont)
                    .foregroundColor(textColor)
                    .frame(width: charWidth(for: char), alignment: .center)
            }
        }
        .shadow(color: Color.shadowLight.opacity(0.6), radius: 12, x: -3, y: -3)
        .shadow(color: Color.shadowDark.opacity(0.25), radius: 10, x: 3, y: 3)
    }
    
    private var timerFont: Font {
        // Prefer Playfair Display if available
        let candidates = [
            "Playfair Display",
            "PlayfairDisplay-Regular",
        ]
        
        if let name = candidates.first(where: { UIFont(name: $0, size: fontSize) != nil }) {
            return .custom(name, size: fontSize)
        }
        
        return .system(size: fontSize, weight: .ultraLight, design: .serif)
    }
    
    private func charWidth(for char: Character) -> CGFloat {
        // Colons are narrower than digits
        if char == ":" {
            return fontSize * 0.35
        }
        // All digits get the same fixed width (based on widest digit, typically 0 or 8)
        return fontSize * 0.62
    }
}

#Preview {
    ZStack {
        Color.neumorphicBackground.ignoresSafeArea()
        TabularTimerText(text: "00:12:34", fontSize: 92)
    }
}
