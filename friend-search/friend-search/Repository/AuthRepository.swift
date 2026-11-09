import Foundation

/// 認証（Cognito）
protocol AuthRepository {
    func isSignedIn() async throws -> Bool
    func signIn(email: String, password: String) async throws -> SignInOutcome
    func signOut() async throws
}

final class DefaultAuthRepository: AuthRepository {
    private let api: any CognitoAuthAPI

    init(api: any CognitoAuthAPI = DefaultCognitoAuthAPI()) {
        self.api = api
    }

    func isSignedIn() async throws -> Bool {
        try await withAppErrors { try await api.isSignedIn() }
    }

    func signIn(email: String, password: String) async throws -> SignInOutcome {
        try await withAppErrors { SignInOutcome(apiModel: try await api.signIn(email: email, password: password)) }
    }

    func signOut() async throws {
        try await withAppErrors { try await api.signOut() }
    }
}
