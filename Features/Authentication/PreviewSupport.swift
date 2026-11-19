//
//  PreviewSupport.swift
//  iOSApprenticeProject
//
//  In-memory stand-ins so SwiftUI previews never touch the network or the real cache.
//

import Foundation

#if DEBUG
final class PreviewAuthRepository: AuthRepository {
    func authStateChanges() -> AsyncStream<AuthUser?> { AsyncStream { $0.yield(nil) } }
    func signIn(email: String, password: String) async throws -> AuthUser { AuthUser(id: UUID(), email: email) }
    func signUp(name: String, email: String, password: String) async throws -> AuthUser? { nil }
    func verifySignUp(email: String, code: String) async throws -> AuthUser { AuthUser(id: UUID(), email: email) }
    func resendConfirmation(email: String) async throws {}
    func signOut() async throws {}
}

extension AppEnvironment {
    static func preview() -> AppEnvironment {
        AppEnvironment(modelContainer: makeContainer(inMemory: true), remote: SupabaseRemote(),
                       isOnline: { false })
    }
}

extension AuthViewModel {
    static func preview() -> AuthViewModel {
        AuthViewModel(repository: PreviewAuthRepository(), env: .preview())
    }
}
#endif
