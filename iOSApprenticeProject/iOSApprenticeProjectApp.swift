//
//  iOSApprenticeProjectApp.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/10/26.
//

import SwiftUI

@main
struct iOSApprenticeProjectApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
