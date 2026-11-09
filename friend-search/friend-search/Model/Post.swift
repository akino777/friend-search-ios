import Foundation

/// VC ツール（単一選択）。rawValue は API 契約の値
nonisolated enum VCTool: String, CaseIterable, Identifiable, Sendable {
    case none
    case discord
    case line
    case inGame = "in_game"
    case playstationParty = "playstation_party"
    case xboxParty = "xbox_party"
    case other

    var id: String { rawValue }
}

/// サーバー上の募集状態
nonisolated enum PostStatus: String, Sendable {
    case open
    case closed
}

nonisolated struct Post: Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let gameId: String
    let author: PublicProfile
    let body: String
    let vcTool: VCTool
    /// 投稿者を除く募集枠
    let capacity: Int
    let participantCount: Int
    let status: PostStatus
    let isJoinedByMe: Bool
    let isOwnedByMe: Bool
    let createdAt: Date
    var inviteUrl: String? = nil
}

/// カーソルページングの1ページ
nonisolated struct PostPage: Sendable {
    let items: [Post]
    let nextCursor: String?
}

/// 募集作成の内容
nonisolated struct NewPost: Sendable, Equatable {
    let gameId: String
    let body: String
    let vcTool: VCTool
    let capacity: Int
    var inviteUrl: String? = nil
}

// MARK: - APIModel ⇄ Model

nonisolated extension Post {
    init(apiModel: PostResponseAPIModel) throws {
        // 不明な値を別の値に置き換えず、契約違反として扱う
        guard let vcTool = VCTool(rawValue: apiModel.vcTool) else {
            throw ModelConversionError.unknownVCTool(apiModel.vcTool)
        }
        guard let status = PostStatus(rawValue: apiModel.status) else {
            throw ModelConversionError.unknownPostStatus(apiModel.status)
        }
        guard let createdAt = ISO8601.date(from: apiModel.createdAt) else {
            throw ModelConversionError.invalidDate(apiModel.createdAt)
        }
        self.init(
            id: apiModel.id,
            gameId: apiModel.gameId,
            author: PublicProfile(apiModel: apiModel.author),
            body: apiModel.body,
            vcTool: vcTool,
            capacity: apiModel.capacity,
            participantCount: apiModel.participantCount,
            status: status,
            isJoinedByMe: apiModel.isJoinedByMe,
            isOwnedByMe: apiModel.isOwnedByMe,
            createdAt: createdAt,
            inviteUrl: apiModel.inviteUrl
        )
    }
}

nonisolated extension PostPage {
    init(apiModel: PostPageResponseAPIModel) throws {
        self.init(items: try apiModel.items.map(Post.init(apiModel:)), nextCursor: apiModel.nextCursor)
    }
}

nonisolated extension NewPost {
    func toAPIModel(clientRequestId: UUID) -> CreatePostRequestAPIModel {
        CreatePostRequestAPIModel(
            gameId: gameId,
            body: body,
            vcTool: vcTool.rawValue,
            capacity: capacity,
            clientRequestId: clientRequestId.uuidString.lowercased(),
            inviteUrl: inviteUrl
        )
    }
}

/// API の日時文字列（小数秒の有無どちらも受け付ける）
nonisolated enum ISO8601 {
    // 変換器を募集ごとに作らない
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plain = Date.ISO8601FormatStyle()

    static func date(from string: String) -> Date? {
        (try? fractional.parse(string)) ?? (try? plain.parse(string))
    }
}
