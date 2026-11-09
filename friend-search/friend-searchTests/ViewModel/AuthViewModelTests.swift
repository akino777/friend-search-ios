import Foundation
import Testing

// 認証画面の ViewModel: 入力検証と結果に応じた遷移。依存は UseCase のモックのみ。

@MainActor
struct SignInViewModelTests {
    let signIn = MockSignInUseCase()

    func make(email: String = " User@Example.com ", password: String = "Passw0rd") -> SignInViewModel {
        let viewModel = SignInViewModel(signIn: signIn)
        viewModel.email = email
        viewModel.password = password
        return viewModel
    }

    @Test func メールアドレスを正規化してサインインする() async {
        signIn.handler = { _, _ in .signedIn }
        #expect(await make().submit())
        #expect(signIn.emails == ["user@example.com"])
    }

    @Test func 形式が不正なメールアドレスは送らない() async {
        let viewModel = make(email: "user@")
        #expect(await viewModel.submit() == false)
        #expect(viewModel.errorMessage == EmailRule.invalidMessage)
        #expect(signIn.emails.isEmpty)
    }

    @Test func 対応しない追加手順は成功扱いにしない() async {
        signIn.handler = { _, _ in .unsupportedStep }
        let viewModel = make()
        #expect(await viewModel.submit() == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func 認証エラーを表示する() async {
        signIn.handler = { _, _ in throw AppError.auth(.invalidCredentials) }
        let viewModel = make()
        #expect(await viewModel.submit() == false)
        #expect(viewModel.errorMessage == AuthFailure.invalidCredentials.message)
    }
}
