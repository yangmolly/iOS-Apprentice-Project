//
//  SignUpFormTests.swift
//  StudySpotTests
//

import Testing
@testable import iOSApprenticeProject

struct SignUpFormTests {
    private let valid = SignUpForm(name: "Alice", email: "alice@gmail.com",
                                   password: "password1", confirmPassword: "password1", agreed: true)

    @Test func emptyFormFlagsEveryFieldInScreenOrder() {
        let form = SignUpForm()
        for field in SignUpForm.Field.allCases {
            #expect(form.error(for: field) != nil, "\(field)")
        }
        #expect(form.firstInvalidField == .name)
        #expect(!form.isValid)
    }

    @Test func validFormHasNoErrors() {
        #expect(valid.isValid)
        #expect(valid.firstError == nil)
    }

    @Test func emailMessagesDistinguishEmptyFromMalformed() {
        var form = valid
        form.email = "   "
        #expect(form.error(for: .email) == "Please enter your email address.")
        form.email = "alice@gmail"
        #expect(form.error(for: .email)?.contains("doesn't look like an email") == true)
        form.email = " Alice@Gmail.com "
        #expect(form.error(for: .email) == nil)
    }

    @Test func passwordCountsDownToTheMinimum() {
        var form = valid
        form.password = ""
        #expect(form.error(for: .password) == "Please create a password with at least 8 characters.")
        form.password = "abcdef"
        #expect(form.error(for: .password) == "Almost there: add 2 more characters.")
        form.password = "abcdefg"
        #expect(form.error(for: .password) == "Almost there: add 1 more character.")
        form.password = "abcdefgh"
        #expect(form.error(for: .password) == nil)
    }

    @Test func confirmationMustMatch() {
        var form = valid
        form.confirmPassword = ""
        #expect(form.error(for: .confirm) == "Please type your password again.")
        form.confirmPassword = "password2"
        #expect(form.error(for: .confirm) == "These passwords don't match yet.")
    }

    @Test func firstInvalidFieldSkipsFixedOnes() {
        var form = valid
        form.confirmPassword = "nope"
        form.agreed = false
        #expect(form.firstInvalidField == .confirm)
        form.confirmPassword = form.password
        #expect(form.firstInvalidField == .terms)
    }
}
