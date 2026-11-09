import Amplify
import Foundation
import Testing

// Repository 層: API の結果を Model と AppError へ置き換える。依存は Data のモックのみ。

@MainActor
struct PostRepositoryTests {
    let api = MockFriendSearchAPI()
    var repository: DefaultPostRepository { DefaultPostRepository(api: api) }

    @Test func 一覧をカーソル付きで取得しModelに変換する() async throws {
        var received: (gameId: String?, cursor: String?)?
        api.listPostsHandler = { gameId, cursor in
            received = (gameId, cursor)
            return PostPageResponseAPIModel(items: [APIFixture.post(id: "p1")], nextCursor: "c1")
        }
        let page = try await repository.listPosts(gameId: "g", cursor: "c0")
        #expect(received?.gameId == "g")
        #expect(received?.cursor == "c0")
        #expect(page.items.map(\.id) == ["p1"])
        #expect(page.nextCursor == "c1")
    }

    @Test func AI検索はゲーム未指定ならgameIdなしで送りModelに変換する() async throws {
        var received: PostSearchRequestAPIModel?
        api.searchPostsHandler = { body in
            received = body
            return PostSearchResponseAPIModel(items: [APIFixture.post(id: "p1")])
        }
        let posts = try await repository.search(gameId: nil, query: "まったり", vcTool: .discord)
        let request = try #require(received)
        #expect(request.gameId == nil)
        #expect(request.query == "まったり")
        #expect(request.vcTool == "discord")
        #expect(posts.map(\.id) == ["p1"])
    }

    @Test func 業務エラーをAppErrorに置き換える() async {
        api.joinPostHandler = { _ in throw APIFixture.error(409, code: "POST_FULL") }
        await #expect(throws: AppError.postFull) { try await repository.join(postId: "p1") }
    }

    @Test func 契約外の応答は不正な応答として扱う() async {
        api.getPostHandler = { _ in
            PostResponseAPIModel(
                id: "p1", gameId: "g", body: "本文", vcTool: "skype", capacity: 3, participantCount: 0, status: "open",
                isJoinedByMe: false, isOwnedByMe: false, createdAt: "2026-11-01T10:00:00Z", author: APIFixture.author
            )
        }
        await #expect(throws: AppError.invalidResponse) { try await repository.post(id: "p1") }
    }
}

@MainActor
struct ProfileRepositoryTests {
    let api = MockFriendSearchAPI()

    @Test func 作成済みならプロフィールを返す() async throws {
        api.fetchMeHandler = { APIFixture.author }
        #expect(try await DefaultProfileRepository(api: api).myProfile() == .found(Fixture.author))
    }

    @Test func 未作成の404はアイコン情報付きの未作成にする() async throws {
        api.fetchMeHandler = {
            throw APIFixture.error(404, code: "PROFILE_NOT_FOUND", avatar: .init(publicUserId: "u1", avatarVersion: 2))
        }
        let lookup = try await DefaultProfileRepository(api: api).myProfile()
        #expect(lookup == .notCreated(avatar: AvatarIdentity(publicUserId: "u1", avatarVersion: 2)))
    }

    @Test func 未作成以外のエラーはAppErrorにする() async {
        api.fetchMeHandler = { throw URLError(.timedOut) }
        await #expect(throws: AppError.network) { try await DefaultProfileRepository(api: api).myProfile() }
    }
}

@MainActor
struct GameRepositoryTests {
    let api = MockFriendSearchAPI()

    @Test func マスタを取得してModelに変換する() async throws {
        api.fetchGamesHandler = { GameCatalogAPIModel(games: [GameAPIModel(id: "g", displayName: "新作", aliases: [], active: true)]) }
        #expect(try await DefaultGameRepository(api: api).games().map(\.id) == ["g"])
    }
}

@MainActor
struct AuthRepositoryTests {
    let api = MockCognitoAuthAPI()
    var repository: DefaultAuthRepository { DefaultAuthRepository(api: api) }

    @Test func ログイン切れはログインし直すエラーにする() async {
        api.isSignedInHandler = { throw AuthError.sessionExpired("expired", "sign in", nil) }
        await #expect(throws: AppError.unauthorized) { try await repository.isSignedIn() }
    }
}
