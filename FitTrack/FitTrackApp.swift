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
    @StateObject private var authViewModel: AuthViewModel

    init() {
        FirebaseApp.configure()
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
        .onChange(of: scenePhase) { _, phase in
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
