import Foundation

// 募集・VC ツールの表示用の値（ボタンの有効・無効は便利機能で、最終判定はサーバー）

/// 画面に表示する募集状態（満員はサーバー上の状態ではなく派生状態）
enum PostDisplayState: Equatable {
    case recruiting
    case full
    case closed

    var label: String {
        switch self {
        case .recruiting: "募集中"
        case .full: "満員"
        case .closed: "終了"
        }
    }
}

extension Post {
    var displayState: PostDisplayState {
        if status == .closed { return .closed }
        return participantCount >= capacity ? .full : .recruiting
    }

    var canJoin: Bool { !isOwnedByMe && !isJoinedByMe && displayState == .recruiting }
    var canClose: Bool { isOwnedByMe && status == .open }

    /// 参加ボタンの文言（参加できない状態ならその理由）
    var joinButtonTitle: String { displayState == .recruiting ? "参加する" : displayState.label }

    /// 招待リンク。投稿者と参加者にだけ見せ、https 以外は開かない
    var visibleInviteLink: URL? {
        guard isOwnedByMe || isJoinedByMe, let inviteUrl, let url = URL(string: inviteUrl), url.scheme == "https" else { return nil }
        return url
    }

    /// 未参加の人に「参加すると招待リンクを見られる」と案内するか
    var showsInviteLinkHint: Bool { !isOwnedByMe && !isJoinedByMe && vcTool.usesInviteLink }
}

extension VCTool {
    var displayName: String {
        switch self {
        case .none: "VCなし"
        case .discord: "Discord"
        case .line: "LINE"
        case .inGame: "ゲーム内VC"
        case .playstationParty: "PlayStationパーティー"
        case .xboxParty: "Xboxパーティー"
        case .other: "その他"
        }
    }

    var systemImage: String { self == .none ? "mic.slash" : "mic" }

    /// 招待リンクを扱うツールか
    var usesInviteLink: Bool { !PostInputRule.inviteHosts(for: self).isEmpty }
}
