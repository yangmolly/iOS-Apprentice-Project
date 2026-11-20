//
//  AuthViewModelTests.swift
//  StudySpotTests
//

import Foundation
import Testing
@testable import iOSApprenticeProject

final class MockAuthRepository: AuthRepository {
    let (stream, continuation) = AsyncStream<AuthUser?>.makeStream()
    var signInResult: Result<AuthUser, Error> = .success(AuthUser(id: Fixtures.userId, email: "alice@unc.edu"))
    var signUpResult: Result<AuthUser?, Error> = .success(nil)
    var verifyResult: Result<AuthUser, Error> = .success(AuthUser(id: Fixtures.userId, email: "alice@unc.edu"))
    private(set) var calls: [String] = []

    func authStateChanges() -> AsyncStream<AuthUser?> { stream }
    func signIn(email: String, password: String) async throws -> AuthUser {
        calls.append("signIn:\(email)"); return try signInResult.get()
    }
    func signUp(name: String, email: String, password: String) async throws -> AuthUser? {
        calls.append("signUp:\(name):\(email)"); return try signUpResult.get()
    }
    func verifySignUp(email: String, code: String) async throws -> AuthUser {
        calls.append("verify:\(email):\(code)"); return try verifyResult.get()
    }
    func resendConfirmation(email: String) async throws { calls.append("resend:\(email)") }
    func signOut() async throws { calls.append("signOut") }
}

struct EmailNotConfirmed: LocalizedError {
    var errorDescription: String? { "Email not confirmed" }
}

struct AuthValidationTests {
    @Test(arguments: ["onyen@unc.edu", "  Onyen@UNC.EDU ", "first.last@gmail.com", "a@ad.unc.edu"])
    func acceptsAnyDomain(_ email: String) {
        #expect(AuthViewModel.isValidEmail(email))
    }

    @Test(arguments: ["onyen", "@unc.edu", "a@b@unc.edu", "onyen@", "onyen@localhost",
                      "onyen@.com", "onyen@gmail.", "onyen@gmail..com", "on yen@unc.edu", ""])
    func rejectsMalformedEmails(_ email: String) {
        #expect(!AuthViewModel.isValidEmail(email))
    }

    @Test func signUpValidationOrder() {
        let ok = (name: "Alice", email: "alice@unc.edu", pw: "password1")
        #expect(AuthViewModel.validateSignUp(name: " ", email: ok.email, password: ok.pw, confirmPassword: ok.pw, agreed: true) == "Please enter your name.")
        #expect(AuthViewModel.validateSignUp(name: ok.name, email: "not-an-email", password: ok.pw, confirmPassword: ok.pw, agreed: true)?.hasPrefix("That doesn't look like an email") == true)
        #expect(AuthViewModel.validateSignUp(name: ok.name, email: ok.email, password: "short", confirmPassword: "short", agreed: true) == "Almost there: add 3 more characters.")
        #expect(AuthViewModel.validateSignUp(name: ok.name, email: ok.email, password: ok.pw, confirmPassword: "different", agreed: true) == "These passwords don't match yet.")
        #expect(AuthViewModel.validateSignUp(name: ok.name, email: ok.email, password: ok.pw, confirmPassword: ok.pw, agreed: false) == "Please agree to the Terms and Privacy Policy to continue.")
        #expect(AuthViewModel.validateSignUp(name: ok.name, email: ok.email, password: ok.pw, confirmPassword: ok.pw, agreed: true) == nil)
    }

    @Test func friendlyMessages() {
        #expect(AuthViewModel.friendlyMessage(for: URLError(.notConnectedToInternet)).contains("offline"))
        struct E: LocalizedError { var errorDescription: String? { "Invalid login credentials" } }
        #expect(AuthViewModel.friendlyMessage(for: E()) == "Wrong email or password.")
    }
}

@MainActor
struct AuthViewModelTests {
    private func make() -> (AuthViewModel, MockAuthRepository, TestEnv) {
        let t = TestEnv(signedIn: false)
        let repo = MockAuthRepository()
        return (AuthViewModel(repository: repo, env: t.env), repo, t)
    }

    @Test func startsLaunchingThenFollowsStoredSession() async throws {
        let (vm, repo, t) = make()
        #expect(vm.phase == .launching)
        vm.start()
        repo.continuation.yield(AuthUser(id: Fixtures.userId, email: "alice@unc.edu"))
        try await waitUntil { vm.phase == .signedIn }
        #expect(t.env.session.userId == Fixtures.userId)

        repo.continuation.yield(nil)
        try await waitUntil { vm.phase == .signedOut }
        #expect(t.env.session.userId == nil)
    }

    @Test func noStoredSessionShowsSignIn() async throws {
        let (vm, repo, _) = make()
        vm.start()
        repo.continuation.yield(nil)
        try await waitUntil { vm.phase == .signedOut }
    }

    @Test func signInRejectsMalformedEmailWithoutCallingServer() async {
        let (vm, repo, _) = make()
        await vm.signIn(email: "alice", password: "password1")
        #expect(vm.errorMessage == "Enter a valid email address.")
        #expect(repo.calls.isEmpty)
    }

    @Test func signInSuccessNormalizesEmailAndSignsIn() async {
        let (vm, repo, t) = make()
        await vm.signIn(email: " Alice@UNC.edu ", password: "password1")
        #expect(repo.calls == ["signIn:alice@unc.edu"])
        #expect(vm.phase == .signedIn)
        #expect(t.env.session.userId == Fixtures.userId)
        #expect(vm.errorMessage == nil)
    }

    @Test func signInWithUnconfirmedEmailOffersCode() async {
        let (vm, repo, _) = make()
        repo.signInResult = .failure(EmailNotConfirmed())
        await vm.signIn(email: "alice@unc.edu", password: "password1")
        #expect(vm.pendingConfirmationEmail == "alice@unc.edu")
        #expect(vm.errorMessage == nil)
        #expect(vm.infoMessage != nil)
    }

    @Test func signUpNeedingConfirmationThenVerify() async {
        let (vm, repo, t) = make()
        await vm.signUp(name: " Alice ", email: "alice@unc.edu", password: "password1",
                        confirmPassword: "password1", agreed: true)
        #expect(repo.calls == ["signUp:Alice:alice@unc.edu"])
        #expect(vm.pendingConfirmationEmail == "alice@unc.edu")
        #expect(vm.phase != .signedIn)

        await vm.verify(code: "12345")
        #expect(vm.errorMessage == "Enter the 6-digit code from your email.")

        await vm.verify(code: "123456")
        #expect(repo.calls.last == "verify:alice@unc.edu:123456")
        #expect(vm.phase == .signedIn)
        #expect(vm.pendingConfirmationEmail == nil)
        #expect(t.env.session.userId == Fixtures.userId)
    }

    @Test func resendUsesPendingEmail() async {
        let (vm, repo, _) = make()
        vm.pendingConfirmationEmail = "alice@unc.edu"
        await vm.resendCode()
        #expect(repo.calls == ["resend:alice@unc.edu"])
        #expect(vm.infoMessage?.contains("alice@unc.edu") == true)
    }

    @Test func signOutClearsLocalData() async throws {
        let (vm, repo, t) = make()
        await vm.signIn(email: "alice@unc.edu", password: "password1")
        t.connectivity.isOnline = false
        try await t.env.saved.setSaved(UUID(), in: .favorite, true)
        #expect(t.env.sync.pendingCount == 1)

        await vm.signOut()
        #expect(repo.calls.last == "signOut")
        #expect(vm.phase == .signedOut)
        #expect(t.env.session.userId == nil)
        #expect(t.env.saved.saved.isEmpty)
        #expect(t.env.sync.pendingCount == 0)
    }
}

/// Polls a main-actor condition (auth state arrives through an async stream).
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now > deadline {
            Issue.record("Timed out waiting for condition")
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}
