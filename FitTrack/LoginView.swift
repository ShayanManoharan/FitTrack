import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textContentType(isCreatingAccount ? .newPassword : .password)
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isCreatingAccount ? "Create Account" : "Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                }

                Section {
                    Button(isCreatingAccount ? "Already have an account? Sign In" : "Create a new account") {
                        isCreatingAccount.toggle()
                        authViewModel.clearError()
                    }
                }

                if let errorMessage = authViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("FitTrack")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isCreatingAccount ? "Create Account" : "Sign In")
                        .font(.headline)
                }
            }
        }
    }

    private func submit() {
        if isCreatingAccount {
            authViewModel.signUp(email: email, password: password)
        } else {
            authViewModel.signIn(email: email, password: password)
        }
    }
}
