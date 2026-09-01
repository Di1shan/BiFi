import SwiftUI

// MARK: - Lock View
struct LockView: View {
    @Bindable var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.primary)
                
                Text("DualBudget")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Locked")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if authManager.canUseBiometrics {
                    Button {
                        authManager.authenticate()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: authManager.biometricType.icon)
                                .font(.title2)
                            Text("Unlock with \(authManager.biometricType.displayName)")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(authManager.isAuthenticating)
                    .padding(.horizontal, 40)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                        
                        Text("Biometric authentication not available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Please disable App Lock in Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                
                if let error = authManager.authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            if authManager.canUseBiometrics {
                authManager.authenticate()
            }
        }
    }
}

#Preview {
    LockView(authManager: AuthenticationManager())
}
