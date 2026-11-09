import Foundation
import Testing

// ViewModel 層の表示用の処理: ゲーム候補検索・Identicon・募集の表示状態・エラーの文言

@MainActor
struct GameSearchIndexTests {
    let index = GameSearchIndex(games: [
        Game(id: "monster-hunter-wilds", displayName: "モンスターハンターワイルズ", aliases: ["Monster Hunter Wilds", "モンハン", "MHWs"], isActive: true),
        Game(id: "apex-legends", displayName: "Apex Legends", aliases: ["エーペックス"], isActive: true),
        Game(id: "hunter-x", displayName: "Hunter X Quest", aliases: [], isActive: true),
        Game(id: "retired", displayName: "モンスター旧作", aliases: [], isActive: false),
    ])

    @Test func 別名と大文字小文字を吸収する() {
        #expect(index.search("mhws").map(\.id) == ["monster-hunter-wilds"])
        #expect(index.search("APEX").map(\.id) == ["apex-legends"])
    }

    @Test func 全角英数とひらがなと空白を吸収する() {
        #expect(index.search("ＭＨＷｓ").map(\.id) == ["monster-hunter-wilds"])
        #expect(index.search("もんはん").map(\.id) == ["monster-hunter-wilds"])
        #expect(index.search("  えーぺっくす ").map(\.id) == ["apex-legends"])
        #expect(index.search("monster   hunter").map(\.id) == ["monster-hunter-wilds"])
    }

    @Test func 前方一致を部分一致より優先する() {
        #expect(index.search("hunter").map(\.id) == ["hunter-x", "monster-hunter-wilds"])
    }

    @Test func 無効なゲームは出さず空の入力なら有効なゲームをすべて出す() {
        #expect(!index.search("モンスター").map(\.id).contains("retired"))
        #expect(index.search("存在しないゲーム").isEmpty)
        #expect(Set(index.search("").map(\.id)) == ["monster-hunter-wilds", "apex-legends", "hunter-x"])
    }
}

/// iOS / Android 共通の Identicon 仕様
@MainActor
struct IdenticonPatternTests {
    @Test func 公開IDの大文字小文字を区別しない() {
        let a = IdenticonPattern(publicUserId: "B24683EC-304D-40F6-A1D1-8C8E52A3D09D", avatarVersion: 1)
        let b = IdenticonPattern(publicUserId: "b24683ec-304d-40f6-a1d1-8c8e52a3d09d", avatarVersion: 1)
        #expect(a == b)
    }

    @Test func 既知の入力で期待値と一致する() {
        // 入力 "1:b24683ec-304d-40f6-a1d1-8c8e52a3d09d" の SHA-256 から仕様どおりに求めた値（Python で算出）
        let pattern = IdenticonPattern(publicUserId: "b24683ec-304d-40f6-a1d1-8c8e52a3d09d", avatarVersion: 1)
        let expected: [[Int]] = [[0, 1, 1, 1, 0], [0, 0, 0, 0, 0], [1, 0, 0, 0, 1], [1, 0, 1, 0, 1], [0, 1, 1, 1, 0]]
        #expect(pattern.cells.map { $0.map { $0 ? 1 : 0 } } == expected)
        #expect(pattern.palette == IdenticonPalette.all[4])
        #expect(pattern.palette.background == 0xEFF6FF)
    }

    @Test func 左右対称の5x5() {
        let pattern = IdenticonPattern(publicUserId: UUID().uuidString, avatarVersion: 1)
        #expect(pattern.cells.count == 5)
        for row in pattern.cells {
            #expect(row.count == 5)
            #expect(row[0] == row[4] && row[1] == row[3])
        }
    }

    @Test func 版が変われば別のパターンになる() {
        let a = IdenticonPattern(publicUserId: "b24683ec-304d-40f6-a1d1-8c8e52a3d09d", avatarVersion: 1)
        let b = IdenticonPattern(publicUserId: "b24683ec-304d-40f6-a1d1-8c8e52a3d09d", avatarVersion: 2)
        #expect(a != b)
    }
}

@MainActor
struct PostPresentationTests {
    func post(count: Int, status: PostStatus = .open, owned: Bool = false, joined: Bool = false) -> Post {
        Post(
            id: "p", gameId: "g", author: Fixture.author, body: "本文", vcTool: .discord, capacity: 3, participantCount: count,
            status: status, isJoinedByMe: joined, isOwnedByMe: owned, createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test func 表示状態() {
        #expect(post(count: 2).displayState == .recruiting)
        #expect(post(count: 3).displayState == .full)
        #expect(post(count: 0, status: .closed).displayState == .closed)
    }

    @Test func 参加と終了のボタン() {
        #expect(post(count: 0).canJoin)
        #expect(!post(count: 3).canJoin)
        #expect(!post(count: 0, joined: true).canJoin)
        #expect(!post(count: 0, owned: true).canJoin)
        #expect(post(count: 0, owned: true).canClose)
        #expect(!post(count: 0, status: .closed, owned: true).canClose)
    }

    @Test func 招待リンクは投稿者と参加者にだけhttpsのものを見せる() {
        func post(owned: Bool = false, joined: Bool = false, link: String? = "https://discord.gg/abc") -> Post {
            var post = self.post(count: 0, owned: owned, joined: joined)
            post.inviteUrl = link
            return post
        }
        #expect(post(joined: true).visibleInviteLink == URL(string: "https://discord.gg/abc"))
        #expect(post(owned: true).visibleInviteLink != nil)
        #expect(post().visibleInviteLink == nil)
        #expect(post().showsInviteLinkHint)
        #expect(post(joined: true, link: "http://discord.gg/abc").visibleInviteLink == nil)
    }

    @Test func 参加ボタンの文言() {
        #expect(post(count: 0).joinButtonTitle == "参加する")
        #expect(post(count: 3).joinButtonTitle == PostDisplayState.full.label)
    }

    @Test func 招待リンクを扱うツール() {
        #expect(Set(VCTool.allCases.filter(\.usesInviteLink)) == [.discord, .line])
    }
}

@MainActor
struct ErrorMessageTests {
    @Test func サーバーのメッセージがあればそれを表示する() {
        #expect(AppError.forbidden(serverMessage: "自分の募集には参加できません").message == "自分の募集には参加できません")
        #expect(AppError.forbidden(serverMessage: nil).message == "この操作は許可されていません")
        #expect(AppError.server(status: 500, serverMessage: nil).message == "サーバーエラーが発生しました（500）")
    }}
