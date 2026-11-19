//
//  iOSApprenticeProjectApp.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/10/26.
//

import SwiftData
import SwiftUI

@main
struct iOSApprenticeProjectApp: App {
    @State private var env: AppEnvironment
    @State private var auth: AuthViewModel

    init() {
        let env = AppEnvironment.live()
        _env = State(initialValue: env)
        _auth = State(initialValue: AuthViewModel(repository: SupabaseAuthRepository(), env: env))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(env)
                .environment(auth)
                .modelContainer(env.modelContainer)
        }
    }
}
