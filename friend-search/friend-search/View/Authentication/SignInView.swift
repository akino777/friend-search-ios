import SwiftUI

/// A03 ログイン
struct SignInView: View {
    @State private var viewModel: SignInViewModel
    let message: String?
    let onSignedIn: () -> Void

    init(viewModel: SignInViewModel, message: String?, onSignedIn: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.message = message
        self.onSignedIn = onSignedIn
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill").font(.system(size: 48)).foregroundStyle(.tint)
                    Text("friend-search").font(.largeTitle.bold())
                    Text("一緒に遊ぶ仲間をゲームごとに探そう").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }
            if let message {
                Section { FormMessage(text: message, kind: .info) }
            }
            Section("ログイン") {
                TextField("メールアドレス", text: $viewModel.email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("signIn.email")
                SecureField("パスワード", text: $viewModel.password)
                    .textContentType(.password)
                    .accessibilityIdentifier("signIn.password")
                if let error = viewModel.errorMessage { FormMessage(text: error) }
                SubmitButton(title: "ログイン", isLoading: viewModel.isLoading, isEnabled: viewModel.canSubmit) {
                    Task { if await viewModel.submit() { onSignedIn() } }
                }
                .accessibilityIdentifier("signIn.submit")
            }
        }
        .navigationTitle("ログイン")
        .navigationBarTitleDisplayMode(.inline)
    }
}
