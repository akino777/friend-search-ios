import Foundation

nonisolated struct CreatePostRequestAPIModel: Encodable, Sendable {
    let gameId: String
    let body: String
    let vcTool: String
    let capacity: Int
    let clientRequestId: String
    var inviteUrl: String? = nil
}

nonisolated struct PostSearchRequestAPIModel: Encodable, Sendable {
    /// nil なら全ゲーム
    let gameId: String?
    let query: String
    let vcTool: String?
}
