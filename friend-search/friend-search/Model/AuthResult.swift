import Amplify
import Foundation

/// サインインの結果
nonisolated enum SignInOutcome: Sendable, Equatable {
    case signedIn
    /// MFA など、このアプリが対応しない追加手順
    case unsupportedStep
}

// MARK: - APIModel（Amplify の結果型）→ Model

nonisolated extension SignInOutcome {
    init(apiModel: AuthSignInResult) {
        switch apiModel.nextStep {
        case .done: self = .signedIn
        default: self = .unsupportedStep
        }
    }
}
