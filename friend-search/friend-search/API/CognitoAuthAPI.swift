import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore

/// Cognito 認証（Amplify.Auth）。Amplify の結果型を APIModel としてそのまま返す（ログイン状態とトークンは値だけ返す）。
protocol CognitoAuthAPI {
    /// 端末に保存されたセッションでログイン中か
    func isSignedIn() async throws -> Bool
    /// 業務 API 用の Access Token（期限切れなら Amplify が更新してから返す）
    func accessToken() async throws -> String
    func signIn(email: String, password: String) async throws -> AuthSignInResult
    func signOut() async throws
}

/// インスタンスはいくつ作ってもよい（Amplify の設定はプロセス全体で一度だけ行う）
final class DefaultCognitoAuthAPI: CognitoAuthAPI {
    /// 最初に使うときに一度だけ、Terraform 管理の既存 User Pool へ接続する（失敗した結果も保持し、以後の呼び出しで同じエラーを返す）
    private static let configuration = Result<Void, any Error> {
        try Amplify.add(plugin: AWSCognitoAuthPlugin())
        try Amplify.configure(AmplifyOutputsData(auth: .init(
            awsRegion: Endpoint.awsRegion,
            userPoolId: Endpoint.userPoolId,
            userPoolClientId: Endpoint.userPoolClientId,
            usernameAttributes: [.email]
        )))
    }

    private var auth: any AuthCategoryBehavior {
        get throws {
            try Self.configuration.get()
            return Amplify.Auth
        }
    }

    func isSignedIn() async throws -> Bool {
        try await auth.fetchAuthSession(options: nil).isSignedIn
    }

    func accessToken() async throws -> String {
        guard let tokens = try await auth.fetchAuthSession(options: nil) as? AuthCognitoTokensProvider else {
            throw AuthError.signedOut("Not a Cognito session", "Sign in again")
        }
        return try tokens.getCognitoTokens().get().accessToken
    }

    func signIn(email: String, password: String) async throws -> AuthSignInResult {
        try await auth.signIn(username: email, password: password, options: nil)
    }

    /// `.partial`（トークン失効のみ失敗）もローカルのサインアウトは完了しているため成功扱い
    func signOut() async throws {
        if case .failed(let error) = try await auth.signOut(options: nil) as? AWSCognitoSignOutResult {
            throw error
        }
    }
}
