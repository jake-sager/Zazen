//
//  CylindricalPicker.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import SwiftUI
import UIKit

struct CylindricalPicker: View {
    @Binding var value: Int
    let range: Range<Int>
    
    private let pickerHeight: CGFloat = 180
    private let pickerWidth: CGFloat = 72
    private let wallWidth: CGFloat = 10
    
    // Haptic feedback generator
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    
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
        .onAppear {
            // Prepare haptic generators
            impactGenerator.prepare()
        }
    }
    
    private var pickerContent: some View {
        ZStack {
            // Background - warm paper-toned gray
            Color(red: 0.68, green: 0.66, blue: 0.62)
            
            // Drum surface
            drumSurface
                .padding(.horizontal, wallWidth)
                .allowsHitTesting(false)
            
            NativeWheelPicker(
                value: $value,
                values: values,
                width: innerWidth,
                height: pickerHeight,
                onTick: triggerTickFeedback
            )
            // Make the native wheel hittable across the full visible picker width.
            .frame(width: pickerWidth, height: pickerHeight)
            .contentShape(Rectangle())
            
            // Side walls
            HStack(spacing: 0) {
                leftWall
                Spacer()
                rightWall
            }
            .allowsHitTesting(false)
            
            // Depth shadows
            VStack(spacing: 0) {
                topShadow
                Spacer()
                bottomShadow
            }
            .padding(.horizontal, wallWidth)
            .allowsHitTesting(false)
        }
        .frame(width: pickerWidth, height: pickerHeight)
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
    
    private func triggerTickFeedback() {
        // Haptic feedback
        impactGenerator.impactOccurred(intensity: 0.6)
        
        // Click sound
        SoundManager.shared.playTickSound()
    }
}

private struct NativeWheelPicker: UIViewRepresentable {
    @Binding var value: Int
    let values: [Int]
    let width: CGFloat
    let height: CGFloat
    let onTick: () -> Void
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView(frame: .zero)
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.backgroundColor = .clear
        picker.setValue(UIColor.clear, forKey: "backgroundColor")
        
        // Initial selection (no tick)
        let idx = values.firstIndex(of: value) ?? 0
        context.coordinator.isProgrammaticSelection = true
        picker.selectRow(idx, inComponent: 0, animated: false)
        DispatchQueue.main.async {
            context.coordinator.isProgrammaticSelection = false
        }
        
        // Hide default separator lines so our custom drum styling reads cleanly
        DispatchQueue.main.async {
            context.coordinator.hideSeparators(in: picker)
        }
        
        return picker
    }
    
    func updateUIView(_ picker: UIPickerView, context: Context) {
        let idx = values.firstIndex(of: value) ?? 0
        if picker.selectedRow(inComponent: 0) != idx {
            context.coordinator.isProgrammaticSelection = true
            picker.selectRow(idx, inComponent: 0, animated: true)
            picker.reloadAllComponents()
            DispatchQueue.main.async {
                context.coordinator.isProgrammaticSelection = false
            }
        }
        
        // UIPickerView sometimes re-adds/reshows separator views during layout updates.
        DispatchQueue.main.async {
            context.coordinator.hideSeparators(in: picker)
        }
    }
    
    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        private let parent: NativeWheelPicker
        fileprivate var isProgrammaticSelection = false
        
        init(_ parent: NativeWheelPicker) {
            self.parent = parent
        }
        
        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            parent.values.count
        }
        
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            56
        }
        
        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            parent.width
        }
        
        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label: UILabel
            if let existing = view as? UILabel {
                label = existing
            } else {
                label = UILabel()
                label.textAlignment = .center
                label.backgroundColor = .clear
            }
            
            let selectedRow = pickerView.selectedRow(inComponent: 0)
            let isSelected = row == selectedRow
            
            label.text = String(format: "%02d", parent.values[row])
            label.font = UIFont.systemFont(ofSize: isSelected ? 34 : 30, weight: isSelected ? .medium : .regular)
            label.textColor = UIColor(isSelected ? Color.textPrimary : Color.textSecondary)
            label.alpha = isSelected ? 1.0 : 0.72
            
            return label
        }
        
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            guard row >= 0, row < parent.values.count else { return }
            parent.value = parent.values[row]
            
            // Update label styles around the selection.
            pickerView.reloadAllComponents()
            
            // Only tick for user-driven scrolling.
            if !isProgrammaticSelection {
                parent.onTick()
            }
        }
        
        fileprivate func hideSeparators(in pickerView: UIPickerView) {
            for subview in pickerView.subviews where subview.frame.height <= 1.5 {
                subview.isHidden = true
            }
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
