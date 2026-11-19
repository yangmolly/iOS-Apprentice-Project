//
//  UserSession.swift
//  iOSApprenticeProject
//

import Foundation
import Observation

/// The signed-in user, shared by every repository. Set by AuthViewModel.
@Observable
final class UserSession {
    var userId: UUID?
    var email: String?

    init(userId: UUID? = nil, email: String? = nil) {
        self.userId = userId
        self.email = email
    }
}

struct NotSignedInError: LocalizedError {
    var errorDescription: String? { "You're signed out. Sign in again to continue." }
}

extension UserSession {
    func requireUserId() throws -> UUID {
        guard let userId else { throw NotSignedInError() }
        return userId
    }
}
