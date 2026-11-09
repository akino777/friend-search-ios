import Amplify
import AWSCognitoAuthPlugin
import Foundation

/// アプリ内で扱う通信・認証のエラー。表示する文言は ViewModel が決める。
nonisolated enum AppError: Error, Equatable, Sendable {
    // 業務 API（サーバーが返したメッセージがあれば保持する）
    case validation(serverMessage: String?)
    case unknownGame
    case unauthorized
    case forbidden(serverMessage: String?)
    case profileRequired
    case profileNotFound
    case notFound
    case postFull
    case postClosed
    case idempotencyConflict
    case concurrentUpdate
    case rateLimited
    case searchUnavailable
    case temporarilyUnavailable
    case server(status: Int, serverMessage: String?)
    // 通信・応答
    case network
    case invalidResponse
    case unexpected
    // 認証
    case auth(AuthFailure)
}

/// Cognito の認証エラー
nonisolated enum AuthFailure: Equatable, Sendable {
    case invalidCredentials
    case limitExceeded
    case userNotFound
    case unexpected(detail: String)
}

// MARK: - API / SDK のエラー → AppError

nonisolated extension AppError {
    init(error: Error) {
        switch error {
        case let appError as AppError: self = appError
        case let http as HTTPErrorAPIModel: self.init(apiModel: http)
        case let authError as AuthError: self.init(apiModel: authError)
        case is ModelConversionError, is DecodingError: self = .invalidResponse
        case is URLError: self = .network
        default: self = .unexpected
        }
    }

    /// エラーコードで分類する。API Gateway が生成する 401 / 429 等は共通形式の本文がないため HTTP ステータスで分類する
    init(apiModel: HTTPErrorAPIModel) {
        let message = apiModel.body?.error.message
        switch (apiModel.statusCode, apiModel.body?.error.code) {
        case (_, "UNKNOWN_GAME"): self = .unknownGame
        case (_, "PROFILE_NOT_FOUND"): self = .profileNotFound
        case (_, "PROFILE_REQUIRED"): self = .profileRequired
        case (_, "POST_FULL"): self = .postFull
        case (_, "POST_CLOSED"): self = .postClosed
        case (_, "IDEMPOTENCY_CONFLICT"): self = .idempotencyConflict
        case (_, "CONCURRENT_UPDATE"): self = .concurrentUpdate
        case (_, "SEARCH_UNAVAILABLE"): self = .searchUnavailable
        case (400, _): self = .validation(serverMessage: message)
        case (401, _): self = .unauthorized
        case (403, _): self = .forbidden(serverMessage: message)
        case (404, _): self = .notFound
        case (409, _): self = .concurrentUpdate
        case (429, _): self = .rateLimited
        case (503, _): self = .temporarilyUnavailable
        case let (status, _): self = .server(status: status, serverMessage: message)
        }
    }

    /// セッション切れはログインし直し、通信障害は再試行できるエラーにする
    init(apiModel error: AuthError) {
        switch error {
        case .signedOut, .sessionExpired:
            self = .unauthorized
            return
        default:
            break
        }
        if error.underlyingError is URLError {
            self = .network
            return
        }
        switch error.underlyingError as? AWSCognitoAuthError {
        case .network: self = .network
        case .limitExceeded, .requestLimitExceeded, .failedAttemptsLimitExceeded, .limitExceededException: self = .auth(.limitExceeded)
        case .userNotFound: self = .auth(.userNotFound)
        default:
            if case .notAuthorized = error {
                self = .auth(.invalidCredentials)
            } else {
                self = .auth(.unexpected(detail: error.errorDescription))
            }
        }
    }
}
