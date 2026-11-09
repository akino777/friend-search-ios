import Foundation
import Observation

@MainActor
@Observable
final class SignInViewModel {
    var email = ""
    var password = ""
    private(set) var isLoading = false
    var errorMessage: String?

    private let signIn: any SignInUseCase

    init(signIn: any SignInUseCase = DefaultSignInUseCase()) {
        self.signIn = signIn
    }

    var canSubmit: Bool { !email.isEmpty && !password.isEmpty && !isLoading }

    /// ログインできたら true
    func submit() async -> Bool {
        guard !isLoading else { return false }
        guard let normalizedEmail = EmailRule.normalized(email) else {
            errorMessage = EmailRule.invalidMessage
            return false
        }
        guard !password.isEmpty else {
            errorMessage = "パスワードを入力してください"
            return false
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch try await signIn.execute(email: normalizedEmail, password: password) {
            case .signedIn:
                return true
            case .unsupportedStep:
                // MFA などの追加手順があっても成功扱いにしない
                errorMessage = "このアカウントには追加の認証手順が設定されているため、このアプリではログインできません"
                return false
            }
        } catch {
            errorMessage = AppError(error: error).message
            return false
        }
    }
}
