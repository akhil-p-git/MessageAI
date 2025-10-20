//
//  SignUpView.swift
//  MessageAI
//
//  Sign up screen with email/password registration
//

import SwiftUI

struct SignUpView: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AuthViewModel
    
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    @FocusState private var focusedField: Field?
    
    // MARK: - Focus Field Enum
    
    enum Field {
        case displayName, email, password, confirmPassword
    }
    
    // MARK: - Body
    
    var body: some View {
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
                        .frame(height: 20)
                    
                    // Logo and App Name
                    logoSection
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Sign Up Form
                    signUpFormSection
                    
                    // Password Requirements
                    passwordRequirementsSection
                    
                    // Error Message
                    if let errorMessage = viewModel.errorMessage {
                        errorMessageView(errorMessage)
                    }
                    
                    // Sign Up Button
                    signUpButton
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Divider
                    dividerSection
                    
                    // Login Link
                    loginSection
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            
            // Loading Overlay
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                    }
                    .foregroundColor(.firebaseOrange)
                }
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
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.firebaseOrange.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "bolt.fill")
                    .font(.system(size: 35, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // App Name
            Text("Create Account")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.firebaseOrange, Color.firebaseRed],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Join MessageAI today")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Sign Up Form Section
    
    private var signUpFormSection: some View {
        VStack(spacing: 16) {
            // Display Name Field
            VStack(alignment: .leading, spacing: 8) {
                Label("Display Name", systemImage: "person.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Enter your name", text: $displayName)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .email
                    }
            }
            
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
                
                SecureField("Create a password", text: $password)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .confirmPassword
                    }
            }
            
            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                Label("Confirm Password", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                SecureField("Confirm your password", text: $confirmPassword)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit {
                        handleSignUp()
                    }
                    .overlay(alignment: .trailing) {
                        if !confirmPassword.isEmpty {
                            passwordMatchIndicator
                                .padding(.trailing, 12)
                        }
                    }
            }
        }
    }
    
    // MARK: - Password Requirements Section
    
    private var passwordRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password Requirements:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Image(systemName: password.count >= 6 ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(password.count >= 6 ? .green : .secondary)
                    .font(.caption)
                
                Text("At least 6 characters")
                    .font(.caption)
                    .foregroundColor(password.count >= 6 ? .green : .secondary)
            }
            
            HStack(spacing: 8) {
                Image(systemName: passwordsMatch && !password.isEmpty ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(passwordsMatch && !password.isEmpty ? .green : .secondary)
                    .font(.caption)
                
                Text("Passwords match")
                    .font(.caption)
                    .foregroundColor(passwordsMatch && !password.isEmpty ? .green : .secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Password Match Indicator
    
    private var passwordMatchIndicator: some View {
        Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundColor(passwordsMatch ? .green : .red)
            .font(.body)
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
    
    // MARK: - Sign Up Button
    
    private var signUpButton: some View {
        Button(action: handleSignUp) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text("Create Account")
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
    
    // MARK: - Login Section
    
    private var loginSection: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                dismiss()
            }) {
                Text("Login")
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
                
                Text("Creating your account...")
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
    
    private var passwordsMatch: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }
    
    private var isPasswordValid: Bool {
        password.count >= 6
    }
    
    private var isFormValid: Bool {
        !displayName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        isValidEmail(email) &&
        isPasswordValid &&
        passwordsMatch
    }
    
    // MARK: - Methods
    
    private func handleSignUp() {
        // Dismiss keyboard
        focusedField = nil
        
        // Clear any previous errors
        viewModel.errorMessage = nil
        
        // Validate display name
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            viewModel.errorMessage = "Please enter your display name."
            return
        }
        
        guard displayName.trimmingCharacters(in: .whitespaces).count >= 2 else {
            viewModel.errorMessage = "Display name must be at least 2 characters."
            return
        }
        
        // Validate email format
        guard isValidEmail(email) else {
            viewModel.errorMessage = "Please enter a valid email address."
            return
        }
        
        // Validate password length
        guard password.count >= 6 else {
            viewModel.errorMessage = "Password must be at least 6 characters."
            return
        }
        
        // Validate passwords match
        guard passwordsMatch else {
            viewModel.errorMessage = "Passwords do not match."
            return
        }
        
        // Attempt sign up
        Task {
            await viewModel.signUp(
                email: email.lowercased().trimmingCharacters(in: .whitespaces),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespaces)
            )
            
            // If successful, dismiss to go back to login or main app
            if viewModel.isAuthenticated {
                dismiss()
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Preview

#if DEBUG
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SignUpView()
                .environmentObject(AuthViewModel())
        }
    }
}
#endif

