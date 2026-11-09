import Foundation

/// 共通エラー形式 `{ "error": { "code", "message", "pendingAvatar" } }`
nonisolated struct ErrorResponseAPIModel: Decodable, Sendable {
    nonisolated struct Body: Decodable, Sendable {
        let code: String
        let message: String
        let pendingAvatar: PendingAvatar?
    }

    nonisolated struct PendingAvatar: Decodable, Sendable {
        let publicUserId: String
        let avatarVersion: Int
    }

    let error: Body
}

/// HTTP エラー応答。Gateway 生成の応答など本文が共通形式でない場合、body は nil
nonisolated struct HTTPErrorAPIModel: Error, Sendable {
    let statusCode: Int
    let body: ErrorResponseAPIModel?
}
