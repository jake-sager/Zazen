//
//  Appearance.swift
//  Zazen
//
//  Created by Jake Sager on 4/19/26.
//

import SwiftUI

/// User-selectable appearance preference. `.system` follows the device, while
/// `.light` / `.dark` force a specific palette regardless of the OS setting.
enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// SwiftUI `ColorScheme` to pass to `.preferredColorScheme(...)`.
    /// `nil` means "follow system".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var displayLabel: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

/// Shared `UserDefaults` key used by both the app (via `@AppStorage`) and by
/// non-SwiftUI callers like `LiveActivityManager` that need to read the
/// preference imperatively.
enum AppearanceStorage {
    static let key = "appearance_mode"

    static var current: AppearanceMode {
        let raw = UserDefaults.standard.string(forKey: key) ?? AppearanceMode.system.rawValue
        return AppearanceMode(rawValue: raw) ?? .system
    }
}
