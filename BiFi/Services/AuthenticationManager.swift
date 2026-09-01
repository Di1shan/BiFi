import Foundation
import LocalAuthentication
import SwiftUI

// MARK: - Authentication Manager
@Observable
final class AuthenticationManager {
    var isUnlocked: Bool = false
    var isAuthenticating: Bool = false
    var authError: String?
    var biometricType: BiometricType = .none
    
    enum BiometricType {
        case none
        case faceID
        case touchID
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "lock.fill"
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            }
        }
    }
    
    init() {
        checkBiometricType()
    }
    
    func checkBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }
    
    var canUseBiometrics: Bool {
        biometricType != .none
    }
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            authError = "Biometric authentication not available"
            return
        }
        
        isAuthenticating = true
        authError = nil
        
        let reason = "Unlock BiFi"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                
                if success {
                    self.isUnlocked = true
                    self.authError = nil
                } else {
                    self.isUnlocked = false
                    if let error = authenticationError as? LAError {
                        switch error.code {
                        case .userCancel:
                            self.authError = "Authentication cancelled"
                        case .userFallback:
                            self.authError = "Fallback authentication not supported"
                        case .biometryNotAvailable:
                            self.authError = "Biometric authentication not available"
                        case .biometryNotEnrolled:
                            self.authError = "No biometric data enrolled"
                        case .biometryLockout:
                            self.authError = "Biometric authentication locked out"
                        default:
                            self.authError = "Authentication failed"
                        }
                    } else {
                        self.authError = "Authentication failed"
                    }
                }
            }
        }
    }
    
    func lock() {
        isUnlocked = false
    }
}
