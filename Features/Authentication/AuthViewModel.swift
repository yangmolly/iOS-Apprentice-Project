//
//  AuthViewModel.swift
//  iOSApprenticeProject
//
//  App-wide sign-in state. Created once in the App file and shared
//  with every view through the environment.
//

import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// True when sign-up worked but Supabase still wants the email confirmed.
    @Published var needsEmailConfirmation = false
    @Published var currentUserId: UUID?

    /// Call on launch so returning users stay signed in.
    func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            currentUserId = session.user.id
            isSignedIn = true
        } catch {
            currentUserId = nil
            isSignedIn = false
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your email and password."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            currentUserId = session.user.id
            isSignedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(name: String, email: String, password: String, confirmPassword: String, agreed: Bool) async {
        errorMessage = nil
        needsEmailConfirmation = false

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter your name."
            return
        }
        guard email.contains("@") else {
            errorMessage = "Enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match."
            return
        }
        guard agreed else {
            errorMessage = "Please agree to the Terms and Privacy Policy."
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            // The "name" is stored in user metadata; the database trigger
            // copies it into the profiles table.
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(name)]
            )
            if let session = response.session {
                currentUserId = session.user.id
                isSignedIn = true
            } else {
                needsEmailConfirmation = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
        currentUserId = nil
        isSignedIn = false
    }
}
