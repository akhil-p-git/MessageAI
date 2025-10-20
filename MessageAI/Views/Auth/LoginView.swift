//
//  LoginView.swift
//  MessageAI
//
//  Login screen with email/password authentication
//

import SwiftUI

struct LoginView: View {
    
    // MARK: - Properties
    
    @EnvironmentObject var viewModel: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    
    @FocusState private var focusedField: Field?
    
    // MARK: - Focus Field Enum
    
    enum Field {
        case email, password
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.white, Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        Spacer()
                            .frame(height: 40)
                        
                        // Logo and App Name
                        logoSection
                        
                        Spacer()
                            .frame(height: 20)
                        
                        // Login Form
                        loginFormSection
                        
                        // Error Message
                        if let errorMessage = viewModel.errorMessage {
                            errorMessageView(errorMessage)
                        }
                        
                        // Login Button
                        loginButton
                        
                        // Forgot Password
                        forgotPasswordButton
                        
                        Spacer()
                            .frame(height: 20)
                        
                        // Divider
                        dividerSection
                        
                        // Sign Up Link
                        signUpSection
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
                
                // Loading Overlay
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .navigationDestination(isPresented: $showingSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
    
    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: 12) {
            // App Icon/Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.firebaseOrange, Color.firebaseRed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.firebaseOrange.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "bolt.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // App Name
            Text("MessageAI")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.firebaseOrange, Color.firebaseRed],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Welcome back!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Login Form Section
    
    private var loginFormSection: some View {
        VStack(spacing: 16) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Label("Email", systemImage: "envelope.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Label("Password", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        handleLogin()
                    }
            }
        }
    }
    
    // MARK: - Error Message View
    
    private func errorMessageView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .foregroundColor(.white)
        .padding()
        .background(Color.red)
        .cornerRadius(12)
        .shadow(color: Color.red.opacity(0.3), radius: 5, x: 0, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: viewModel.errorMessage)
    }
    
    // MARK: - Login Button
    
    private var loginButton: some View {
        Button(action: handleLogin) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text("Login")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: viewModel.isLoading || !isFormValid
                        ? [Color.gray, Color.gray]
                        : [Color.firebaseOrange, Color.firebaseRed],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(
                color: viewModel.isLoading || !isFormValid
                    ? Color.clear
                    : Color.firebaseOrange.opacity(0.4),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(viewModel.isLoading || !isFormValid)
        .animation(.easeInOut, value: viewModel.isLoading)
    }
    
    // MARK: - Forgot Password Button
    
    private var forgotPasswordButton: some View {
        Button(action: {
            showingForgotPassword = true
        }) {
            Text("Forgot Password?")
                .font(.subheadline)
                .foregroundColor(.firebaseOrange)
        }
    }
    
    // MARK: - Divider Section
    
    private var dividerSection: some View {
        HStack(spacing: 16) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))
            
            Text("or")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))
        }
    }
    
    // MARK: - Sign Up Section
    
    private var signUpSection: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                showingSignUp = true
            }) {
                Text("Sign Up")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.firebaseOrange)
            }
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Signing in...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .opacity(0.95)
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && isValidEmail(email)
    }
    
    // MARK: - Methods
    
    private func handleLogin() {
        // Dismiss keyboard
        focusedField = nil
        
        // Clear any previous errors
        viewModel.errorMessage = nil
        
        // Validate email format
        guard isValidEmail(email) else {
            viewModel.errorMessage = "Please enter a valid email address."
            return
        }
        
        // Attempt login
        Task {
            await viewModel.signIn(email: email.lowercased().trimmingCharacters(in: .whitespaces), password: password)
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

// MARK: - Firebase Colors

extension Color {
    static let firebaseOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let firebaseRed = Color(red: 1.0, green: 0.27, blue: 0.0)
}

// MARK: - Forgot Password View (Placeholder)

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                Text("Reset Password")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Label("Email", systemImage: "envelope.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 24)
                
                // Success message
                if showingSuccess {
                    Text("Password reset email sent! Check your inbox.")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
                // Send Button
                Button(action: {
                    // TODO: Implement password reset functionality
                    // Note: sendPasswordReset method needs to be added to AuthViewModel
                    showingSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }) {
                    Text(viewModel.isLoading ? "Sending..." : "Send Reset Link")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [Color.firebaseOrange, Color.firebaseRed],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .disabled(viewModel.isLoading || email.isEmpty)
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
#endif

