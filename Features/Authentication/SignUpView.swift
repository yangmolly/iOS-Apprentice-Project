//
//  SignUpView.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/18/26.
//

import SwiftUI

struct SignUpView: View {

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var agreed = false

    private enum Field { case name, email, password, confirm }
    @FocusState private var focus: Field?

    private let blue = Color(red: 0.02, green: 0.43, blue: 1.0)
    private let fieldBorder = Color.gray.opacity(0.25)

    var body: some View {
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
                TextField("Name", text: $name)
                    .focused($focus, equals: .name)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .overlay(border(focused: focus == .name))
                    .padding(.top, 8)

                // Email
                label("Email Address").padding(.top, 20)
                TextField("onyen@unc.edu", text: $email)
                    .focused($focus, equals: .email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .overlay(border(focused: focus == .email))
                    .padding(.top, 8)

                // Password
                label("Password").padding(.top, 20)
                passwordField(placeholder: "Create a password",
                              text: $password,
                              show: $showPassword,
                              field: .password)
                    .padding(.top, 8)

                passwordField(placeholder: "Confirm password",
                              text: $confirmPassword,
                              show: $showConfirmPassword,
                              field: .confirm)
                    .padding(.top, 12)

                // Terms checkbox
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        agreed.toggle()
                    } label: {
                        Image(systemName: agreed ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20))
                            .foregroundColor(agreed ? blue : fieldBorder)
                    }

                    Text("I've read and agree with the \(Text("Terms and Conditions").foregroundColor(blue)) and the \(Text("Privacy Policy").foregroundColor(blue)).")
                        .foregroundColor(.gray)
                        .font(.system(size: 11))
                }
                .padding(.top, 20)

                // Sign up button
                Button {
                    // TODO: sign up action
                } label: {
                    Text("Sign up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(blue)
                        .cornerRadius(8)
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white)
        .onAppear { focus = .name }
    }

    // MARK: - Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
    }

    private func border(focused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(focused ? blue : fieldBorder, lineWidth: focused ? 1.5 : 1)
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
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 14))

            Button {
                show.wrappedValue.toggle()
            } label: {
                Image(systemName: show.wrappedValue ? "eye" : "eye.slash")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .overlay(border(focused: focus == field))
    }
}

#Preview {
    SignUpView()
}
