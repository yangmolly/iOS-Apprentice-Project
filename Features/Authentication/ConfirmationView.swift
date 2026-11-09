//
//  ConfirmationView.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/18/26.
//

import SwiftUI

struct ConfirmationCodeView: View {

    @State private var code = ""
    @FocusState private var focused: Bool

    private let email = "onyen@unc.edu"
    private let blue = Color(red: 0.02, green: 0.43, blue: 1.0)
    private let fieldBorder = Color.gray.opacity(0.25)

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Title + subtitle
            Text("Enter confirmation code")
                .font(.system(size: 16, weight: .bold))

            Text("A 4-digit code was sent to\n\(email)")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            // 4 digit boxes
            ZStack {
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        digitBox(at: index)
                    }
                }

                // Hidden field that drives the number pad
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .opacity(0.01)
                    .frame(width: 1, height: 1)
                    .onChange(of: code) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        code = String(digits.prefix(4))
                    }
            }
            .padding(.top, 32)

            Spacer()
            Spacer()

            // Resend code
            Button("Resend code") {
                // TODO: resend code action
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(blue)

            // Continue button
            Button {
                // TODO: verify code action
            } label: {
                Text("Continue")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(blue)
                    .cornerRadius(8)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { focused = true }
    }

    // MARK: - Digit box

    private func digitBox(at index: Int) -> some View {
        let digits = Array(code)
        let isActive = index == code.count && focused

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? blue : fieldBorder, lineWidth: isActive ? 1.5 : 1)

            if index < digits.count {
                Text(String(digits[index]))
                    .font(.system(size: 14))
            }
        }
        .frame(width: 48, height: 48)
    }
}

#Preview {
    ConfirmationCodeView()
}
