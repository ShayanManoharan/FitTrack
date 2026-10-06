//
//  FitTrackApp.swift
//  FitTrack
//
//  Created by Shayan Manoharan on 10/1/26.
//

import SwiftUI
import FirebaseCore

@main
struct FitTrackApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
            FirebaseApp.configure()
        }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                print("[Lifecycle] App active")
            case .inactive:
                print("[Lifecycle] App inactive")
            case .background:
                print("[Lifecycle] App background")
            @unknown default:
                break
            }
        }
    }
}
