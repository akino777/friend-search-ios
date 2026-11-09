import Foundation

nonisolated struct PostResponseAPIModel: Decodable, Sendable {
    let id: String
    let gameId: String
    let body: String
    let vcTool: String
    let capacity: Int
    let participantCount: Int
    let status: String
    let isJoinedByMe: Bool
    let isOwnedByMe: Bool
    let createdAt: String
    let author: ProfileResponseAPIModel
    var inviteUrl: String? = nil
}

nonisolated struct PostPageResponseAPIModel: Decodable, Sendable {
    let items: [PostResponseAPIModel]
    let nextCursor: String?
}

nonisolated struct PostSearchResponseAPIModel: Decodable, Sendable {
    let items: [PostResponseAPIModel]
}
