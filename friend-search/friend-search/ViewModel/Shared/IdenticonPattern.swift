import CryptoKit
import Foundation

/// GitHub 風の 5×5 左右対称 Identicon の表示パターン。iOS / 将来の Android で同じ結果になる共通仕様。
///
/// 1. 入力は `"\(avatarVersion):\(publicUserId.lowercased())"` の UTF-8
/// 2. SHA-256 の 32 バイト digest
/// 3. digest 先頭から 15 ビットを行優先（5行×3列）で読む。各バイトは最上位ビットから
/// 4. 右2列は左2列を左右反転コピー
/// 5. 配色は `digest[15] % 8` で固定パレットから選ぶ
nonisolated struct IdenticonPattern: Sendable, Equatable {
    static let size = 5

    /// cells[row][column]（true = 前景色）
    let cells: [[Bool]]
    let palette: IdenticonPalette

    init(publicUserId: String, avatarVersion: Int) {
        let input = "\(avatarVersion):\(publicUserId.lowercased())"
        let digest = Array(SHA256.hash(data: Data(input.utf8)))
        self.init(digest: digest)
    }

    private init(digest: [UInt8]) {
        precondition(digest.count == 32, "SHA-256 digest must be 32 bytes")
        func bit(_ index: Int) -> Bool {
            (digest[index / 8] >> (7 - UInt8(index % 8))) & 1 == 1
        }
        var rows: [[Bool]] = []
        for row in 0..<Self.size {
            let left = (0..<3).map { bit(row * 3 + $0) }
            rows.append([left[0], left[1], left[2], left[1], left[0]])
        }
        cells = rows
        palette = IdenticonPalette.all[Int(digest[15] % 8)]
    }
}

/// 背景 / 前景（16進RGB）。値は共通仕様として固定する。
nonisolated struct IdenticonPalette: Sendable, Equatable {
    let background: UInt32
    let foreground: UInt32

    static let all: [IdenticonPalette] = [
        .init(background: 0xEEF2FF, foreground: 0x3730A3),
        .init(background: 0xECFDF5, foreground: 0x065F46),
        .init(background: 0xFFF7ED, foreground: 0x9A3412),
        .init(background: 0xFDF2F8, foreground: 0x9D174D),
        .init(background: 0xEFF6FF, foreground: 0x1D4ED8),
        .init(background: 0xF0FDFA, foreground: 0x0F766E),
        .init(background: 0xFEFCE8, foreground: 0x854D0E),
        .init(background: 0xF5F3FF, foreground: 0x6D28D9),
    ]
}
