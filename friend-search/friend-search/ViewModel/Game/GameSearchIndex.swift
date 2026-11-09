import Foundation

/// 端末内のゲーム候補検索（AI は使わない）。表示名・別名を正規化して照合し、前方一致を部分一致より優先する。
/// 正規化した名前は作成時に一度だけ求め、入力のたびに全ゲームを正規化し直さない。
nonisolated struct GameSearchIndex {
    private let entries: [(game: Game, names: [String])]

    init(games: [Game]) {
        entries = games.filter(\.isActive).map { game in
            (game, ([game.displayName] + game.aliases).map(Self.normalize))
        }
    }

    /// 入力が空なら有効なゲームをすべて返す
    func search(_ query: String) -> [Game] {
        let needle = Self.normalize(query)
        guard !needle.isEmpty else { return entries.map(\.game) }
        var prefix: [Game] = []
        var contains: [Game] = []
        for (game, names) in entries {
            if names.contains(where: { $0.hasPrefix(needle) }) {
                prefix.append(game)
            } else if names.contains(where: { $0.contains(needle) }) {
                contains.append(game)
            }
        }
        return prefix + contains
    }

    /// NFKC・ひらがな→カタカナ・小文字化・前後空白の除去・連続空白の圧縮
    static func normalize(_ value: String) -> String {
        let nfkc = value.precomposedStringWithCompatibilityMapping
        let katakana = nfkc.applyingTransform(.hiraganaToKatakana, reverse: false) ?? nfkc
        return katakana
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
