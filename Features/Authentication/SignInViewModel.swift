//
//  SignInViewModel.swift
//  iOSApprenticeProject
//
//  Created by Sarayu Pesala on 10/11/26.
//

import Foundation
import Combine

class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
}
