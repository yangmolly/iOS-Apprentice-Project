//
//  AuthFlowView.swift
//  iOSApprenticeProject
//
//  Sign in -> sign up -> email confirmation code, as one navigation stack.
//

import SwiftUI

struct AuthFlowView: View {
    enum Route: Hashable {
        case signUp
        case confirm
    }

    @Environment(AuthViewModel.self) private var auth
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            SignInView(onRegister: { path.append(.signUp) })
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .signUp: SignUpView()
                    case .confirm: ConfirmationCodeView()
                    }
                }
        }
        .onChange(of: auth.pendingConfirmationEmail) { _, email in
            if email != nil, path.last != .confirm {
                path.append(.confirm)
            } else if email == nil {
                path.removeAll { $0 == .confirm }
            }
        }
        .onChange(of: path) { _, newPath in
            // Backing out of the code screen abandons that confirmation.
            if !newPath.contains(.confirm), auth.pendingConfirmationEmail != nil {
                auth.pendingConfirmationEmail = nil
            }
        }
    }
}
