//
//  SignUpForm.swift
//  iOSApprenticeProject
//

import Foundation

/// The sign-up fields and their validation rules. Pure, so the screen and
/// `AuthViewModel` share one set of rules and tests can cover them directly.
struct SignUpForm: Equatable {
    enum Field: CaseIterable, Hashable {
        case name, email, password, confirm, terms
    }

    var name = ""
    var email = ""
    var password = ""
    var confirmPassword = ""
    var agreed = false

    /// A friendly message for what's wrong with `field`, or nil when it's fine.
    func error(for field: Field) -> String? {
        switch field {
        case .name:
            return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Please enter your name." : nil
        case .email:
            if AuthViewModel.normalize(email).isEmpty { return "Please enter your email address." }
            return AuthViewModel.isValidEmail(email)
                ? nil : "That doesn't look like an email address. Check for a missing \"@\" or \".com\"."
        case .password:
            let missing = AuthViewModel.minimumPasswordLength - password.count
            guard missing > 0 else { return nil }
            if password.isEmpty {
                return "Please create a password with at least \(AuthViewModel.minimumPasswordLength) characters."
            }
            return "Almost there: add \(missing) more character\(missing == 1 ? "" : "s")."
        case .confirm:
            if confirmPassword.isEmpty { return "Please type your password again." }
            return confirmPassword == password ? nil : "These passwords don't match yet."
        case .terms:
            return agreed ? nil : "Please agree to the Terms and Privacy Policy to continue."
        }
    }

    /// The first field with a problem, in screen order.
    var firstInvalidField: Field? {
        Field.allCases.first { error(for: $0) != nil }
    }

    var firstError: String? { firstInvalidField.flatMap(error(for:)) }
    var isValid: Bool { firstInvalidField == nil }
}
