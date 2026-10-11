//
//  SignInView.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/10/26.
//

import SwiftUI

struct SignInView: View {
    @StateObject private var viewModel = SignInViewModel()
    
    var body: some View {
        TextField("Enter email", text: $viewModel.email)
            .padding()
    }
}
