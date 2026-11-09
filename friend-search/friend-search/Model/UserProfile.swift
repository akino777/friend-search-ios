import Foundation

/// 公開プロフィール（他ユーザーにも表示される情報のみ）
nonisolated struct PublicProfile: Sendable, Equatable, Hashable {
    /// 認証用 ID とは別の乱数 UUID
    let publicUserId: String
    let displayName: String
    let avatarVersion: Int
}

/// アイコンの元になる情報（表示名が決まる前でも扱える）
nonisolated struct AvatarIdentity: Sendable, Equatable {
    let publicUserId: String
    let avatarVersion: Int
}

/// 自分のプロフィールの取得結果
nonisolated enum ProfileLookup: Sendable, Equatable {
    case found(PublicProfile)
    /// 未作成。avatar はサーバーが返す、作成後と同じアイコンの情報
    case notCreated(avatar: AvatarIdentity? = nil)
}

// MARK: - APIModel ⇄ Model

nonisolated extension PublicProfile {
    init(apiModel: ProfileResponseAPIModel) {
        self.init(publicUserId: apiModel.publicUserId, displayName: apiModel.displayName, avatarVersion: apiModel.avatarVersion)
    }
}

nonisolated extension AvatarIdentity {
    init(apiModel: ErrorResponseAPIModel.PendingAvatar) {
        self.init(publicUserId: apiModel.publicUserId, avatarVersion: apiModel.avatarVersion)
    }
}

nonisolated extension ProfileLookup {
    /// エラー応答が「プロフィール未作成」（404 PROFILE_NOT_FOUND）なら `.notCreated`。それ以外は nil
    init?(notFoundError error: Error) {
        guard let http = error as? HTTPErrorAPIModel, http.statusCode == 404,
              let body = http.body?.error, body.code == "PROFILE_NOT_FOUND"
        else { return nil }
        self = .notCreated(avatar: body.pendingAvatar.map(AvatarIdentity.init(apiModel:)))
    }
}
