//
//  CylindricalPicker.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import SwiftUI

struct CylindricalPicker: View {
    @Binding var value: Int
    let range: Range<Int>
    
    private let pickerHeight: CGFloat = 180
    private let itemHeight: CGFloat = 56
    private let pickerWidth: CGFloat = 72
    private let wallWidth: CGFloat = 10
    
    @State private var scrollOffset: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0
    
    private var values: [Int] { Array(range) }
    private var innerWidth: CGFloat { pickerWidth - wallWidth * 2 }
    
    var body: some View {
        ZStack {
            // Neumorphic inset frame
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.neumorphicFrame)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.shadowDark.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color.shadowDark.opacity(0.5), radius: 4, x: 2, y: 2)
                .shadow(color: Color.shadowLight.opacity(0.7), radius: 4, x: -2, y: -2)
            
            // Picker content
            pickerContent
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(5)
        }
        .frame(width: pickerWidth + 20, height: pickerHeight + 10)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .onAppear {
            let index = values.firstIndex(of: value) ?? 0
            scrollOffset = -CGFloat(index) * itemHeight
        }
    }
    
    private var pickerContent: some View {
        ZStack {
            // Background - warm paper-toned gray
            Color(red: 0.68, green: 0.66, blue: 0.62)
            
            // Drum surface
            drumSurface
                .padding(.horizontal, wallWidth)
            
            // Numbers - render fixed 5 slots
            Canvas { context, size in
                let centerY = size.height / 2
                let currentFloat = -scrollOffset / itemHeight
                let centerIndex = Int(round(currentFloat))
                
                // Render 5 items: center ± 2
                for slot in -2...2 {
                    let itemIndex = centerIndex + slot
                    guard itemIndex >= 0 && itemIndex < values.count else { continue }
                    
                    let val = values[itemIndex]
                    let itemOffset = scrollOffset + CGFloat(itemIndex) * itemHeight
                    let normalizedDist = itemOffset / itemHeight
                    let absDistance = abs(normalizedDist)
                    
                    // Skip if too far
                    guard absDistance < 2 else { continue }
                    
                    let opacity = max(0, 1 - absDistance * 0.4)
                    let scale = max(0.75, 1 - absDistance * 0.12)
                    let isSelected = absDistance < 0.5
                    
                    // Calculate position with 3D-like effect
                    let yPos = centerY + itemOffset
                    let fontSize: CGFloat = isSelected ? 34 : 30
                    
                    // Draw number
                    let text = String(format: "%02d", val)
                    var textContext = context
                    
                    // Apply transforms
                    let transform = CGAffineTransform(translationX: size.width / 2, y: yPos)
                        .scaledBy(x: scale, y: scale)
                    textContext.transform = transform
                    
                    // Resolve text
                    let resolved = textContext.resolve(
                        Text(text)
                            .font(.system(size: fontSize, weight: isSelected ? .medium : .regular))
                            .foregroundColor(isSelected ? Color.textPrimary : Color.textSecondary)
                    )
                    
                    textContext.opacity = opacity
                    textContext.draw(resolved, at: .zero)
                    
                    // Draw detent line
                    if absDistance < 1.5 {
                        let lineY = yPos - itemHeight / 2
                        let linePath = Path { p in
                            p.move(to: CGPoint(x: wallWidth, y: lineY))
                            p.addLine(to: CGPoint(x: size.width - wallWidth, y: lineY))
                        }
                        context.stroke(linePath, with: .color(.black.opacity(0.08)), lineWidth: 1)
                        
                        // Center notch
                        let notchPath = Path { p in
                            p.move(to: CGPoint(x: size.width / 2, y: lineY))
                            p.addLine(to: CGPoint(x: size.width / 2, y: lineY + 6))
                        }
                        context.stroke(notchPath, with: .color(.black.opacity(0.10)), lineWidth: 1)
                    }
                }
            }
            .frame(width: pickerWidth, height: pickerHeight)
            
            // Side walls
            HStack(spacing: 0) {
                leftWall
                Spacer()
                rightWall
            }
            
            // Depth shadows
            VStack(spacing: 0) {
                topShadow
                Spacer()
                bottomShadow
            }
            .padding(.horizontal, wallWidth)
            .allowsHitTesting(false)
        }
    }
    
    private var drumSurface: some View {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.925, blue: 0.91),
                Color(red: 0.96, green: 0.955, blue: 0.945),
                Color(red: 0.98, green: 0.975, blue: 0.965),
                Color(red: 0.96, green: 0.955, blue: 0.945),
                Color(red: 0.93, green: 0.925, blue: 0.91)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var leftWall: some View {
        LinearGradient(
            colors: [
                Color(red: 0.52, green: 0.51, blue: 0.49),
                Color(red: 0.58, green: 0.57, blue: 0.55),
                Color(red: 0.64, green: 0.63, blue: 0.61),
                Color(red: 0.70, green: 0.69, blue: 0.67),
                Color(red: 0.74, green: 0.73, blue: 0.71)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: wallWidth)
    }
    
    private var rightWall: some View {
        LinearGradient(
            colors: [
                Color(red: 0.74, green: 0.73, blue: 0.71),
                Color(red: 0.70, green: 0.69, blue: 0.67),
                Color(red: 0.64, green: 0.63, blue: 0.61),
                Color(red: 0.58, green: 0.57, blue: 0.55),
                Color(red: 0.52, green: 0.51, blue: 0.49)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: wallWidth)
    }
    
    private var topShadow: some View {
        LinearGradient(
            colors: [
                Color(red: 0.86, green: 0.85, blue: 0.83).opacity(0.9),
                Color(red: 0.92, green: 0.91, blue: 0.89).opacity(0.5),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 28)
    }
    
    private var bottomShadow: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color(red: 0.92, green: 0.91, blue: 0.89).opacity(0.5),
                Color(red: 0.86, green: 0.85, blue: 0.83).opacity(0.9)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 28)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { gesture in
                let delta = gesture.translation.height - lastDragValue
                lastDragValue = gesture.translation.height
                
                let newOffset = scrollOffset + delta
                let maxOffset: CGFloat = 0
                let minOffset = -CGFloat(values.count - 1) * itemHeight
                scrollOffset = max(minOffset, min(maxOffset, newOffset))
            }
            .onEnded { gesture in
                lastDragValue = 0
                
                let velocity = gesture.velocity.height
                let projectedOffset = scrollOffset + velocity * 0.08
                
                let nearestIndex = Int(round(-projectedOffset / itemHeight))
                let clampedIndex = max(0, min(values.count - 1, nearestIndex))
                let targetOffset = -CGFloat(clampedIndex) * itemHeight
                
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    scrollOffset = targetOffset
                }
                
                value = values[clampedIndex]
            }
    }
}

#Preview {
    ZStack {
        Color.neumorphicBackground.ignoresSafeArea()
        
        HStack(spacing: 4) {
            CylindricalPicker(value: .constant(0), range: 0..<24)
            CylindricalPicker(value: .constant(5), range: 0..<60)
            CylindricalPicker(value: .constant(0), range: 0..<60)
        }
    }
}
