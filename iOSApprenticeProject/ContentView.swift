//
//  ContentView.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/10/26.
//


import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isSignedIn {
                VStack(spacing: 16) {
                    Text("You're signed in!")
                        .font(.title2.bold())
                    Button("Sign out") {
                        Task { await auth.signOut() }
                    }
                }
            } else {
                NavigationStack {
                    SignInView()
                }
            }
        }
        .task {
            await auth.restoreSession()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
