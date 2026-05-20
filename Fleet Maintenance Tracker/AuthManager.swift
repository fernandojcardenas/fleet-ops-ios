//
//  AuthManager.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import Foundation
import Observation
import FirebaseAuth
import FirebaseCore

@MainActor
@Observable
class AuthManager {
    var user: User?
    var errorMessage: String?

    @ObservationIgnored
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        print("[AuthManager] init — FirebaseApp configured: \(FirebaseApp.app() != nil)")
        self.user = Auth.auth().currentUser
        print("[AuthManager] initial currentUser: \(Auth.auth().currentUser?.uid ?? "nil")")
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                print("[AuthManager] auth state changed — user: \(user?.uid ?? "nil")")
                self?.user = user
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    var isLoggedIn: Bool {
        user != nil
    }

    func signIn(email: String, password: String) async {
        print("[AuthManager] signIn → attempting with email: \(email)")
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.user = result.user
            print("[AuthManager] signIn → success, uid: \(result.user.uid)")
        } catch {
            self.errorMessage = error.localizedDescription
            logAuthError(error, label: "signIn")
        }
    }

    func signUp(email: String, password: String) async {
        print("[AuthManager] signUp → attempting with email: \(email)")
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.user = result.user
            print("[AuthManager] signUp → success, uid: \(result.user.uid)")
        } catch {
            self.errorMessage = error.localizedDescription
            logAuthError(error, label: "signUp")
        }
    }

    func signOut() {
        print("[AuthManager] signOut → attempting")
        errorMessage = nil
        do {
            try Auth.auth().signOut()
            self.user = nil
            print("[AuthManager] signOut → success")
        } catch {
            self.errorMessage = error.localizedDescription
            logAuthError(error, label: "signOut")
        }
    }

    private func logAuthError(_ error: Error, label: String) {
        let nsError = error as NSError
        let code = AuthErrorCode(rawValue: nsError.code)?.description ?? "unknown"
        print("[AuthManager] \(label) → ERROR")
        print("  - domain:     \(nsError.domain)")
        print("  - code:       \(nsError.code) (\(code))")
        print("  - localized:  \(error.localizedDescription)")
        if let reason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] {
            print("  - reason:     \(reason)")
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] {
            print("  - underlying: \(underlying)")
        }
    }
}

private extension AuthErrorCode {
    var description: String {
        switch self {
        case .networkError: return "networkError"
        case .userNotFound: return "userNotFound"
        case .wrongPassword: return "wrongPassword"
        case .invalidEmail: return "invalidEmail"
        case .emailAlreadyInUse: return "emailAlreadyInUse"
        case .weakPassword: return "weakPassword"
        case .operationNotAllowed: return "operationNotAllowed (Email/Password sign-in disabled in Firebase Console)"
        case .tooManyRequests: return "tooManyRequests"
        case .keychainError: return "keychainError"
        default: return "AuthErrorCode(\(rawValue))"
        }
    }
}
