//
//  AuthRepository.swift
//  iOSApprenticeProject
//

import Foundation
import Supabase

struct AuthUser: Equatable {
    let id: UUID
    let email: String?
}

protocol AuthRepository: AnyObject {
    /// Emits the current user (or nil) on launch and on every sign-in / sign-out.
    func authStateChanges() -> AsyncStream<AuthUser?>
    func signIn(email: String, password: String) async throws -> AuthUser
    /// Returns nil when the account was created but the email still needs confirming.
    func signUp(name: String, email: String, password: String) async throws -> AuthUser?
    func verifySignUp(email: String, code: String) async throws -> AuthUser
    func resendConfirmation(email: String) async throws
    func signOut() async throws
}

final class SupabaseAuthRepository: AuthRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    func authStateChanges() -> AsyncStream<AuthUser?> {
        let changes = client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await (event, session) in changes {
                    switch event {
                    case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                        // With emitLocalSessionAsInitialSession, an expired stored session still counts:
                        // the user stays signed in offline, and the SDK refreshes the token when it can.
                        continuation.yield(session.map { AuthUser(id: $0.user.id, email: $0.user.email) })
                    case .signedOut, .userDeleted:
                        continuation.yield(nil)
                    default:
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        let session = try await client.auth.signIn(email: email, password: password)
        return AuthUser(id: session.user.id, email: session.user.email)
    }

    func signUp(name: String, email: String, password: String) async throws -> AuthUser? {
        // `name` goes into user metadata; the handle_new_user trigger copies it into profiles.
        let response = try await client.auth.signUp(email: email, password: password,
                                                    data: ["name": .string(name)])
        guard let session = response.session else { return nil }
        return AuthUser(id: session.user.id, email: session.user.email)
    }

    func verifySignUp(email: String, code: String) async throws -> AuthUser {
        let response = try await client.auth.verifyOTP(email: email, token: code, type: .signup)
        guard let session = response.session else {
            throw AuthFlowError.verificationIncomplete
        }
        return AuthUser(id: session.user.id, email: session.user.email)
    }

    func resendConfirmation(email: String) async throws {
        try await client.auth.resend(email: email, type: .signup)
    }

    func signOut() async throws {
        // Local scope: clears the Keychain session without needing the network.
        try await client.auth.signOut(scope: .local)
    }
}

enum AuthFlowError: LocalizedError {
    case verificationIncomplete
    var errorDescription: String? { "That code didn't sign you in. Try signing in with your password." }
}
