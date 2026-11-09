import Foundation

// 画面の入力検証の規則。最終的な判定はサーバーが行う（ここは送信前の補助）。

nonisolated enum EmailRule {
    static let invalidMessage = "メールアドレスの形式が正しくありません"

    /// 前後の空白を除いて小文字にしたメールアドレス。形式が正しくなければ nil
    static func normalized(_ raw: String) -> String? {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return email.wholeMatch(of: #/^[^@\s]+@[^@\s]+\.[^@\s]+$/#) == nil ? nil : email
    }
}

nonisolated enum DisplayNameRule {
    static let range = 2...24
    static let invalidMessage = "表示名は\(range.lowerBound)〜\(range.upperBound)文字で入力してください"

    /// 前後の空白を除いた表示名。文字数が範囲外か制御文字を含めば nil
    static func normalized(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard range.contains(name.count),
              !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else { return nil }
        return name
    }
}

nonisolated enum PostInputRule {
    static let bodyRange = 1...1000
    static let capacityRange = 1...10
    static let defaultCapacity = 2
    static let queryRange = 2...300

    static let gameMissingMessage = "ゲームを選択してください"
    static let bodyMessage = "募集本文は\(bodyRange.lowerBound)〜\(bodyRange.upperBound)文字で入力してください"
    static let capacityMessage = "募集人数は\(capacityRange.lowerBound)〜\(capacityRange.upperBound)の数字で入力してください"
    static let inviteLinkMessage = "選択したツールの HTTPS 招待リンクを入力してください"
    static let queryMessage = "検索文は\(queryRange.lowerBound)〜\(queryRange.upperBound)文字で入力してください"

    static func normalizedBody(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 募集人数。半角数字以外・範囲外なら nil
    static func capacity(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(trimmed) else { return nil }
        return capacityRange.contains(value) ? value : nil
    }

    /// 前後の空白を除いた検索文。文字数が範囲外なら nil
    static func normalizedQuery(_ text: String) -> String? {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return queryRange.contains(query.count) ? query : nil
    }

    /// 招待リンクとして受け付けるホスト。空ならリンクを扱わないツール
    static func inviteHosts(for tool: VCTool) -> Set<String> {
        switch tool {
        case .discord: ["discord.gg", "discord.com"]
        case .line: ["line.me"]
        case .none, .inGame, .playstationParty, .xboxParty, .other: []
        }
    }

    /// 招待リンク。https のみ・ユーザー情報やポート指定なし・ツールの公式ホストのみ受け付ける。不正なら nil
    static func inviteLink(_ raw: String, for tool: VCTool) -> String? {
        let link = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard link.count <= 2048, let components = URLComponents(string: link),
              components.scheme?.lowercased() == "https",
              components.user == nil, components.password == nil, components.port == nil,
              let host = components.host?.lowercased(),
              inviteHosts(for: tool).contains(host)
        else { return nil }
        return link
    }
}
