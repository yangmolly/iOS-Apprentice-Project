//
//  SignUpView.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/18/26.
//

import SwiftUI

struct SignUpView: View {
    typealias Field = SignUpForm.Field

    @State private var form = SignUpForm()
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    /// Fields the user has left (or every field, after tapping Sign up). Errors show only for these,
    /// so nobody is scolded before they've had a chance to type.
    @State private var touched: Set<Field> = []
    @Environment(AuthViewModel.self) private var auth

    @FocusState private var focus: Field?

    private let blue = Color(red: 0.02, green: 0.43, blue: 1.0)
    private let fieldBorder = Color.gray.opacity(0.25)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    Text("Sign up")
                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, 24)

                    Text("Create an account to get started")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.top, 6)

                    // Name
                    label("Name").padding(.top, 28)
                    TextField("Name", text: $form.name)
                        .focused($focus, equals: .name)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .onSubmit { focus = .email }
                        .font(.system(size: 14))
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .overlay(border(for: .name))
                        .padding(.top, 8)
                        .id(Field.name)
                    fieldMessage(for: .name)

                    // Email
                    label("Email Address").padding(.top, 20)
                    TextField("you@example.com", text: $form.email)
                        .focused($focus, equals: .email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                        .font(.system(size: 14))
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .overlay(border(for: .email))
                        .padding(.top, 8)
                        .id(Field.email)
                    fieldMessage(for: .email)

                    // Password
                    label("Password").padding(.top, 20)
                    passwordField(placeholder: "Create a password",
                                  text: $form.password,
                                  show: $showPassword,
                                  field: .password)
                        .padding(.top, 8)
                    fieldMessage(for: .password,
                                 hint: "At least \(AuthViewModel.minimumPasswordLength) characters.")

                    passwordField(placeholder: "Confirm password",
                                  text: $form.confirmPassword,
                                  show: $showConfirmPassword,
                                  field: .confirm)
                        .padding(.top, 12)
                    fieldMessage(for: .confirm)

                    // Terms checkbox
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            form.agreed.toggle()
                            touched.insert(.terms)
                        } label: {
                            Image(systemName: form.agreed ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(form.agreed ? blue : (showsError(.terms) ? .red : fieldBorder))
                        }
                        .accessibilityLabel("Agree to the Terms and Privacy Policy")
                        .accessibilityValue(form.agreed ? "Checked" : "Unchecked")

                        Text("I've read and agree with the \(Text("Terms and Conditions").foregroundColor(blue)) and the \(Text("Privacy Policy").foregroundColor(blue)).")
                            .foregroundColor(.gray)
                            .font(.system(size: 11))
                    }
                    .padding(.top, 20)
                    .id(Field.terms)
                    fieldMessage(for: .terms)

                    // Errors from the server (account exists, offline, …)
                    if let message = auth.errorMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.top, 16)
                    }

                    // Sign up button
                    Button {
                        submit(scrollingWith: proxy)
                    } label: {
                        Group {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(blue)
                        .cornerRadius(8)
                    }
                    .disabled(auth.isLoading)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .animation(.easeOut(duration: 0.15), value: touched)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white)
        .onAppear { focus = .name }
        .onChange(of: focus) { previous, _ in
            if let previous { touched.insert(previous) }
        }
        .onChange(of: form) {
            // A stale server error shouldn't linger once the user starts fixing things.
            if auth.errorMessage != nil { auth.errorMessage = nil }
        }
    }

    // MARK: - Validation

    private func showsError(_ field: Field) -> Bool {
        touched.contains(field) && form.error(for: field) != nil
    }

    private func submit(scrollingWith proxy: ScrollViewProxy) {
        touched = Set(Field.allCases)
        if let field = form.firstInvalidField {
            withAnimation { proxy.scrollTo(field, anchor: .center) }
            focus = field == .terms ? nil : field
            return
        }
        focus = nil
        Task {
            await auth.signUp(name: form.name, email: form.email, password: form.password,
                              confirmPassword: form.confirmPassword, agreed: form.agreed)
        }
    }

    // MARK: - Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
    }

    /// The field's error once it's been touched, otherwise an optional gray hint.
    @ViewBuilder
    private func fieldMessage(for field: Field, hint: String? = nil) -> some View {
        if showsError(field), let message = form.error(for: field) {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.red)
                .padding(.top, 6)
                .transition(.opacity)
                .accessibilityLabel("Error: \(message)")
        } else if let hint {
            Text(hint)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .padding(.top, 6)
        }
    }

    private func border(for field: Field) -> some View {
        let focused = focus == field
        let color: Color = showsError(field) ? .red : (focused ? blue : fieldBorder)
        return RoundedRectangle(cornerRadius: 8)
            .stroke(color, lineWidth: focused || showsError(field) ? 1.5 : 1)
    }

    private func passwordField(placeholder: String,
                               text: Binding<String>,
                               show: Binding<Bool>,
                               field: Field) -> some View {
        HStack {
            Group {
                if show.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .focused($focus, equals: field)
            .textContentType(.newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(field == .password ? .next : .done)
            .onSubmit { focus = field == .password ? .confirm : nil }
            .font(.system(size: 14))

            Button {
                show.wrappedValue.toggle()
            } label: {
                Image(systemName: show.wrappedValue ? "eye" : "eye.slash")
                    .foregroundColor(.gray)
            }
            .accessibilityLabel(show.wrappedValue ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .overlay(border(for: field))
        .id(field)
    }
}

#Preview {
    SignUpView()
        .environment(AuthViewModel.preview())
}
