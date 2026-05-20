//
//  LoginView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Fleet Maintenance Tracker")
                .font(.title)
                .fontWeight(.semibold)

            emailField

            SecureField("Password", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)

            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button("Sign In") {
                Task { await authManager.signIn(email: email, password: password) }
            }
            .buttonStyle(.borderedProminent)

            Button("Sign Up") {
                Task { await authManager.signUp(email: email, password: password) }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var emailField: some View {
        let field = TextField("Email", text: $email)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
        #if os(iOS) || os(tvOS) || os(visionOS)
        return field
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
        #else
        return field
        #endif
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
