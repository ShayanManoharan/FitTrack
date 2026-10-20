import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, email, password }
    private let tabBackground = Color(red: 234 / 255, green: 241 / 255, blue: 239 / 255)

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > 700 && geometry.size.width > geometry.size.height
            if landscape {
                HStack(spacing: 0) {
                    landscapeBrand.frame(width: geometry.size.width * 0.42)
                    ScrollView {
                        loginContent(compact: true)
                            .padding(.horizontal, 48).padding(.top, 15).padding(.bottom, 20)
                            .frame(minHeight: geometry.size.height, alignment: .top)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ScrollView {
                    loginContent(compact: false)
                        .padding(.horizontal, 26)
                        .padding(.top, geometry.size.height < 695 ? 22 : 42)
                        .padding(.bottom, 28)
                        .frame(maxWidth: 480)
                        .frame(minHeight: geometry.size.height, alignment: .top)
                        .frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
            }
        }
        .background(FitTrackStyle.background.ignoresSafeArea())
        .foregroundStyle(FitTrackStyle.ink).tint(FitTrackStyle.accent)
        .preferredColorScheme(.light)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    private var landscapeBrand: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("FITTRACK").font(.system(size: 35, weight: .heavy)).tracking(2)
                .foregroundStyle(.white)
            Text("Build your routine.\nTrack every step.")
                .font(.system(size: 21)).lineSpacing(6)
                .foregroundStyle(Color(red: 223 / 255, green: 244 / 255, blue: 239 / 255))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 48).padding(.top, 80)
        .background(FitTrackStyle.accent.ignoresSafeArea())
        .accessibilityElement(children: .combine)
    }

    private func loginContent(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !compact {
                Text("F").font(.system(size: 28, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 55, height: 55)
                    .background(FitTrackStyle.accent).clipShape(RoundedRectangle(cornerRadius: 17))
                    .shadow(color: FitTrackStyle.accent.opacity(0.2), radius: 11, y: 8)
                    .accessibilityHidden(true)
                Text("FITTRACK").font(.system(size: 12, weight: .heavy)).tracking(1.4)
                    .foregroundStyle(FitTrackStyle.accent).padding(.top, 17).padding(.bottom, 32)
            }
            Text(isCreatingAccount ? "Create your account" : "Welcome back")
                .font(.system(size: compact ? 26 : 30, weight: .bold)).tracking(-1)
                .accessibilityAddTraits(.isHeader)
            Text(isCreatingAccount ? "Start building a workout routine that fits you." : "Sign in to pick up where you left off.")
                .font(.system(size: 14)).foregroundStyle(FitTrackStyle.muted)
                .lineSpacing(3).padding(.top, 7).padding(.bottom, compact ? 8 : 25)
            accountTabs.padding(.bottom, compact ? 5 : 22)
            if isCreatingAccount {
                fieldLabel("Name", compact: compact)
                TextField("Your name", text: $name)
                    .textContentType(.name).textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name).submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .modifier(LoginFieldStyle(focused: focusedField == .name, compact: compact))
                    .accessibilityLabel("Name").accessibilityIdentifier("signupName")
                    .onChange(of: name) { _, value in
                        if value.count > 60 { name = String(value.prefix(60)) }
                    }
            }
            fieldLabel("Email", compact: compact)
            TextField("you@example.com", text: $email)
                .textContentType(.emailAddress).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focusedField, equals: .email).submitLabel(.next)
                .onSubmit { focusedField = .password }
                .modifier(LoginFieldStyle(focused: focusedField == .email, compact: compact))
                .accessibilityLabel("Email").accessibilityIdentifier("loginEmail")
            fieldLabel("Password", compact: compact)
            HStack(spacing: 0) {
                Group {
                    if isPasswordVisible { TextField("Enter your password", text: $password) }
                    else { SecureField("Enter your password", text: $password) }
                }
                .textContentType(isCreatingAccount ? .newPassword : .password)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focusedField, equals: .password).submitLabel(.go)
                .onSubmit { submit() }
                .accessibilityLabel("Password").accessibilityIdentifier("loginPassword")
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Text(isPasswordVisible ? "Hide" : "Show")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(FitTrackStyle.accent)
                        .frame(minWidth: 44, minHeight: 24)
                }.buttonStyle(.plain)
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            }.modifier(LoginFieldStyle(focused: focusedField == .password, compact: compact))
            if let error = authViewModel.errorMessage {
                Text(error).font(.system(size: 12)).foregroundStyle(Color(red: 165 / 255, green: 61 / 255, blue: 55 / 255))
                    .padding(.top, 10).accessibilityIdentifier("loginError")
            } else {
                Color.clear.frame(height: compact ? 10 : 28).accessibilityHidden(true)
            }
            Button(action: submit) {
                Group {
                    if authViewModel.isLoading { ProgressView().tint(.white).accessibilityLabel(isCreatingAccount ? "Creating account" : "Signing in") }
                    else { Text(isCreatingAccount ? "Create account" : "Sign in").font(.system(size: 15, weight: .heavy)) }
                }.frame(maxWidth: .infinity, minHeight: compact ? 44 : 49)
                    .foregroundStyle(.white).background(FitTrackStyle.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }.buttonStyle(.plain)
                .padding(.top, compact ? 10 : 25)
                .disabled(!canSubmit).accessibilityIdentifier("loginSubmit")
            Text(isCreatingAccount
                 ? "Use your email and a password of at least 8 characters to create your account."
                 : "Sign in with your FITTRACK account to access your workouts.")
                .font(.system(size: 12)).foregroundStyle(FitTrackStyle.muted)
                .lineSpacing(3).padding(.top, 13)
            Spacer(minLength: compact ? 10 : 28)
            (
                Text("Move with purpose. ").foregroundStyle(FitTrackStyle.muted)
                + Text("Track your progress.").bold().foregroundStyle(FitTrackStyle.accent)
            ).font(.system(size: 12)).frame(maxWidth: .infinity)
        }
        .disabled(authViewModel.isLoading)
    }

    private var accountTabs: some View {
        HStack(spacing: 0) {
            accountTab("Sign in", signUp: false)
            accountTab("Sign up", signUp: true)
        }.padding(4).background(tabBackground).clipShape(RoundedRectangle(cornerRadius: 13))
            .accessibilityElement(children: .contain).accessibilityLabel("Account access")
    }

    private func accountTab(_ title: String, signUp: Bool) -> some View {
        let selected = isCreatingAccount == signUp
        return Button {
            isCreatingAccount = signUp
            isPasswordVisible = false
            authViewModel.clearError()
            focusedField = nil
        } label: {
            Text(title).font(.system(size: 14, weight: .heavy))
                .foregroundStyle(selected ? FitTrackStyle.accent : FitTrackStyle.muted)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(selected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: selected ? FitTrackStyle.ink.opacity(0.09) : .clear, radius: 3, y: 2)
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func fieldLabel(_ title: String, compact: Bool) -> some View {
        Text(title).font(.system(size: 13, weight: .semibold))
            .padding(.top, compact ? 8 : 14).padding(.bottom, compact ? 5 : 7)
    }

    private var canSubmit: Bool {
        !authViewModel.isLoading && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !password.isEmpty && (!isCreatingAccount || (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 8 && name.count <= 60))
    }

    private func submit() {
        guard canSubmit else { return }
        focusedField = nil
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCreatingAccount {
            authViewModel.signUp(email: email, password: password, name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        } else { authViewModel.signIn(email: email, password: password) }
    }
}

private struct LoginFieldStyle: ViewModifier {
    let focused: Bool
    let compact: Bool
    func body(content: Content) -> some View {
        content.font(.system(size: 14)).padding(.horizontal, 14).padding(.vertical, compact ? 10 : 13)
            .background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? FitTrackStyle.accent : FitTrackStyle.line, lineWidth: focused ? 2 : 1))
    }
}
