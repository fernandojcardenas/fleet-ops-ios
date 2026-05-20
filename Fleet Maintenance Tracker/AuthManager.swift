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
import FirebaseFirestore

enum DeleteAccountResult {
    case success
    case requiresReauth
    case failed(String)
}

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

    func reauthenticate(password: String) async -> Bool {
        print("[AuthManager] reauthenticate → attempting")
        errorMessage = nil
        guard let currentUser = Auth.auth().currentUser,
              let email = currentUser.email else {
            errorMessage = "No signed-in user to re-authenticate."
            return false
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            try await currentUser.reauthenticate(with: credential)
            print("[AuthManager] reauthenticate → success")
            return true
        } catch {
            errorMessage = error.localizedDescription
            logAuthError(error, label: "reauthenticate")
            return false
        }
    }

    func deleteAccount() async -> DeleteAccountResult {
        print("[AuthManager] deleteAccount → attempting")
        errorMessage = nil
        guard let currentUser = Auth.auth().currentUser else {
            let message = "No signed-in user to delete."
            errorMessage = message
            return .failed(message)
        }
        let uid = currentUser.uid

        // Best-effort cleanup of the user's record in the /users collection.
        // A failure here should not prevent the auth account from being deleted.
        do {
            try await Firestore.firestore().collection("users").document(uid).delete()
            print("[AuthManager] deleteAccount → users/\(uid) cleanup succeeded")
        } catch {
            print("[AuthManager] deleteAccount → users/\(uid) cleanup failed: \(error.localizedDescription)")
        }

        do {
            try await currentUser.delete()
            self.user = nil
            print("[AuthManager] deleteAccount → success")
            return .success
        } catch {
            let nsError = error as NSError
            logAuthError(error, label: "deleteAccount")
            if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                return .requiresReauth
            }
            errorMessage = error.localizedDescription
            return .failed(error.localizedDescription)
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
