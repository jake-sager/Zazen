//
//  ZazenApp.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import SwiftUI

@main
struct ZazenApp: App {
    @AppStorage(AppearanceStorage.key) private var appearanceRaw: String = AppearanceMode.system.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // The washi palette is now fully dynamic (light + dark variants
                // in `NeumorphicStyle.swift`), so system-rendered UI (Pickers,
                // DatePickers, sheets) stays legible regardless of the chosen
                // scheme. `nil` here means "follow the device".
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
