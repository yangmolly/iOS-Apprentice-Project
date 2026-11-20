//
//  AuthViewModel.swift
//  iOSApprenticeProject
//
//  App-wide sign-in state. Created once in the App file and shared
//  with every view through the environment.
//

import Foundation
import Observation

@Observable
final class AuthViewModel {
    enum Phase: Equatable {
        /// Waiting for the stored session on launch.
        case launching
        case signedOut
        case signedIn
    }

    static let minimumPasswordLength = 8
    static let codeLength = 6

    private(set) var phase: Phase = .launching
    private(set) var isLoading = false
    var errorMessage: String?
    var infoMessage: String?
    /// Set when an account needs its email confirmed. Drives navigation to the code screen.
    var pendingConfirmationEmail: String?

    @ObservationIgnored private let repository: AuthRepository
    @ObservationIgnored private let env: AppEnvironment
    @ObservationIgnored private var listener: Task<Void, Never>?

    init(repository: AuthRepository, env: AppEnvironment) {
        self.repository = repository
        self.env = env
    }

    /// Start following auth state. Call once on launch.
    func start() {
        guard listener == nil else { return }
        let stream = repository.authStateChanges()
        listener = Task { [weak self] in
            for await user in stream {
                self?.apply(user)
            }
        }
    }

    // MARK: - Actions

    func signIn(email: String, password: String) async {
        clearMessages()
        let email = Self.normalize(email)
        if let problem = Self.validateSignIn(email: email, password: password) {
            errorMessage = problem
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            apply(try await repository.signIn(email: email, password: password))
        } catch {
            if Self.isEmailNotConfirmed(error) {
                pendingConfirmationEmail = email
                infoMessage = "Confirm your email first. We can resend the code."
            } else {
                errorMessage = Self.friendlyMessage(for: error)
            }
        }
    }

    func signUp(name: String, email: String, password: String, confirmPassword: String, agreed: Bool) async {
        clearMessages()
        let email = Self.normalize(email)
        if let problem = Self.validateSignUp(name: name, email: email, password: password,
                                             confirmPassword: confirmPassword, agreed: agreed) {
            errorMessage = problem
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let user = try await repository.signUp(name: name, email: email, password: password) {
                apply(user)
            } else {
                pendingConfirmationEmail = email
            }
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    func verify(code: String) async {
        clearMessages()
        guard let email = pendingConfirmationEmail else { return }
        let digits = code.filter(\.isNumber)
        guard digits.count == Self.codeLength else {
            errorMessage = "Enter the \(Self.codeLength)-digit code from your email."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            apply(try await repository.verifySignUp(email: email, code: digits))
            pendingConfirmationEmail = nil
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    func resendCode() async {
        clearMessages()
        guard let email = pendingConfirmationEmail else { return }
        do {
            try await repository.resendConfirmation(email: email)
            infoMessage = "We sent a new code to \(email)."
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    func signOut() async {
        try? await repository.signOut()
        apply(nil)
    }

    // MARK: - State

    private func apply(_ user: AuthUser?) {
        if let user {
            let isNewUser = env.session.userId != user.id
            env.session.userId = user.id
            env.session.email = user.email
            phase = .signedIn
            if isNewUser {
                env.startSession()
            }
        } else {
            if env.session.userId != nil { env.reset() }
            phase = .signedOut
        }
    }

    private func clearMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    // MARK: - Validation (pure, unit-tested)

    static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// A light shape check (one "@", a dotted domain, no spaces). The server's confirmation email is the real test.
    static func isValidEmail(_ email: String) -> Bool {
        let parts = normalize(email).split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts.joined().contains(" ") else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".") && !domain.contains("..")
    }

    static func validateSignIn(email: String, password: String) -> String? {
        if email.isEmpty || password.isEmpty { return "Enter your email and password." }
        if !isValidEmail(email) { return "Enter a valid email address." }
        return nil
    }

    static func validateSignUp(name: String, email: String, password: String,
                               confirmPassword: String, agreed: Bool) -> String? {
        SignUpForm(name: name, email: email, password: password,
                   confirmPassword: confirmPassword, agreed: agreed).firstError
    }

    static func isEmailNotConfirmed(_ error: Error) -> Bool {
        let text = "\(error) \(error.localizedDescription)".lowercased()
        return text.contains("email_not_confirmed") || text.contains("email not confirmed")
    }

    static func friendlyMessage(for error: Error) -> String {
        if error is URLError { return "You're offline. Check your connection and try again." }
        let text = error.localizedDescription
        if text.lowercased().contains("invalid login credentials") { return "Wrong email or password." }
        return text
    }
}
