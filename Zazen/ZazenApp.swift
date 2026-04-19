//
//  ZazenApp.swift
//  Zazen
//
//  Created by Jake Sager on 1/2/26.
//

import SwiftUI

@main
struct ZazenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // The whole app uses a hardcoded warm-paper palette. Forcing light
                // color scheme keeps system-rendered UI (navigation titles, Picker
                // wheels, DatePickers, etc.) readable on the light background when
                // the device is in dark mode -- otherwise they render with light
                // text that nearly disappears on our paper backgrounds (e.g. the
                // "Add Session" sheet).
                .preferredColorScheme(.light)
        }
    }
}
