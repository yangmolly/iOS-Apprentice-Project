//
//  SignInView.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/10/26.
//



import SwiftUI

struct SignInView: View {

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showSignUp = false
    @EnvironmentObject private var auth: AuthViewModel

    private let blue = Color(red: 0.02, green: 0.43, blue: 1.0)
    private let headerBlue = Color(red: 0.88, green: 0.99, blue: 0.99)
    private let fieldBorder = Color.gray.opacity(0.25)

    var body: some View {
        GeometryReader { geo in
            // Figma frame is 375 x 812. Scale vertical measurements to this screen.
            let fullHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let s = fullHeight / 812
            let bandHeight = max(80 * s - geo.safeAreaInsets.top, 12)

            ScrollView {
                VStack(spacing: 0) {

                    // Top band (status bar area in Figma, ~80pt total)
                    Color.white
                        .frame(height: bandHeight)
                        .frame(maxWidth: .infinity)

                    // Logo image (375 x 300 in Figma)
                    ZStack {
                        headerBlue
                        Image("UNCLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: 300 * s)
                    .clipped()

                    // Form
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Welcome!")
                            .font(.system(size: 24, weight: .bold))
                            .padding(.top, 40 * s)
                            .padding(.bottom, 8)

                        // Email
                        TextField("Enter your @unc.edu email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 14))
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(fieldBorder, lineWidth: 1)
                            )

                        // Password
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 14))

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye" : "eye.slash")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(fieldBorder, lineWidth: 1)
                        )

                        Button("Forgot password?") {
                            // TODO: forgot password action
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(blue)

                        if let message = auth.errorMessage {
                            Text(message)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }

                        // Login button
                        Button {
                            Task { await auth.signIn(email: email, password: password) }
                        } label: {
                            Group {
                                if auth.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Login")
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
                        .padding(.top, 8 * s)

                        // Register
                        HStack(spacing: 4) {
                            Text("Not a member?")
                                .foregroundColor(.gray)
                            Button("Register now") {
                                auth.errorMessage = nil
                                showSignUp = true
                            }
                            .foregroundColor(blue)
                            .fontWeight(.medium)
                        }
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8 * s)

                        Divider()
                            .padding(.top, 8 * s)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.white)
        .navigationDestination(isPresented: $showSignUp) {
            SignUpView()
        }
    }
}

#Preview {
    NavigationStack {
        SignInView()
    }
    .environmentObject(AuthViewModel())
}
