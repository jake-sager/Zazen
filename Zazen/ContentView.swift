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
    @State private var isSessionActive: Bool = false
    
    enum Tab {
        case timer
        case stats
        case settings
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            ZStack {
                PaperTextureBackground()
                    .ignoresSafeArea()
                
                if selectedTab == .timer {
                    TimerView(store: store, settings: timerSettings, isSessionActive: $isSessionActive)
                        .transition(.opacity)
                } else if selectedTab == .settings {
                    SettingsView(timerSettings: timerSettings)
                        .transition(.opacity)
                } else {
                    StatsView(store: store)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            
            // Tab bar - pinned to bottom
            if !isSessionActive {
                tabBar
            }
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

            tabButton(
                icon: "gearshape.fill",
                label: "Settings",
                isSelected: selectedTab == .settings
            ) {
                selectedTab = .settings
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(
            Color.neumorphicCard
                .shadow(color: Color.shadowDark.opacity(0.3), radius: 8, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private func tabButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            // Stop any playing sounds when switching tabs
            SoundManager.shared.stopAllSounds()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color.textPrimary : Color.textMuted)
                
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? Color.textPrimary : Color.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
        }
    }
}

#Preview {
    ContentView()
}
