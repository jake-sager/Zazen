//
//  ContentView.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import SwiftUI

struct ContentView: View {
    @State private var store = MeditationStore()
    @State private var selectedTab: Tab = .timer
    @StateObject private var timerSettings = TimerSettings()
    
    enum Tab {
        case timer
        case stats
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            ZStack {
                PaperTextureBackground()
                    .ignoresSafeArea()
                
                if selectedTab == .timer {
                    TimerView(store: store, settings: timerSettings)
                        .transition(.opacity)
                } else {
                    StatsView(store: store)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            
            // Tab bar - pinned to bottom
            tabBar
        }
        .ignoresSafeArea(.keyboard)
    }
    
    // MARK: - Custom Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(
                icon: "timer",
                label: "Timer",
                isSelected: selectedTab == .timer
            ) {
                selectedTab = .timer
            }
            
            tabButton(
                icon: "chart.bar.fill",
                label: "Stats",
                isSelected: selectedTab == .stats
            ) {
                selectedTab = .stats
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Color.neumorphicCard
                .shadow(color: Color.shadowDark.opacity(0.3), radius: 8, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private func tabButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color.textPrimary : Color.textMuted)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? Color.textPrimary : Color.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    ContentView()
}
