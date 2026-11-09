import Amplify
import Foundation

// Repository 層のテストで差し込む Data（API）のモック。未設定の処理は Unimplemented を投げる。

@MainActor
final class MockFriendSearchAPI: FriendSearchAPI {
    var fetchGamesHandler: () async throws -> GameCatalogAPIModel = { throw Unimplemented() }
    var fetchMeHandler: () async throws -> ProfileResponseAPIModel = { throw Unimplemented() }
    var bootstrapHandler: (DisplayNameRequestAPIModel) async throws -> ProfileResponseAPIModel = { _ in throw Unimplemented() }
    var updateMeHandler: (DisplayNameRequestAPIModel) async throws -> ProfileResponseAPIModel = { _ in throw Unimplemented() }
    var listPostsHandler: (String?, String?) async throws -> PostPageResponseAPIModel = { _, _ in throw Unimplemented() }
    var createPostHandler: (CreatePostRequestAPIModel) async throws -> PostResponseAPIModel = { _ in throw Unimplemented() }
    var getPostHandler: (String) async throws -> PostResponseAPIModel = { _ in throw Unimplemented() }
    var joinPostHandler: (String) async throws -> PostResponseAPIModel = { _ in throw Unimplemented() }
    var leavePostHandler: (String) async throws -> PostResponseAPIModel = { _ in throw Unimplemented() }
    var closePostHandler: (String) async throws -> PostResponseAPIModel = { _ in throw Unimplemented() }
    var searchPostsHandler: (PostSearchRequestAPIModel) async throws -> PostSearchResponseAPIModel = { _ in throw Unimplemented() }
    var myPostsHandler: (String?) async throws -> PostPageResponseAPIModel = { _ in throw Unimplemented() }
    var myParticipationsHandler: (String?) async throws -> PostPageResponseAPIModel = { _ in throw Unimplemented() }

    func fetchGames() async throws -> GameCatalogAPIModel { try await fetchGamesHandler() }
    func fetchMe() async throws -> ProfileResponseAPIModel { try await fetchMeHandler() }
    func bootstrap(_ body: DisplayNameRequestAPIModel) async throws -> ProfileResponseAPIModel { try await bootstrapHandler(body) }
    func updateMe(_ body: DisplayNameRequestAPIModel) async throws -> ProfileResponseAPIModel { try await updateMeHandler(body) }
    func listPosts(gameId: String?, cursor: String?) async throws -> PostPageResponseAPIModel { try await listPostsHandler(gameId, cursor) }
    func createPost(_ body: CreatePostRequestAPIModel) async throws -> PostResponseAPIModel { try await createPostHandler(body) }
    func getPost(id: String) async throws -> PostResponseAPIModel { try await getPostHandler(id) }
    func joinPost(id: String) async throws -> PostResponseAPIModel { try await joinPostHandler(id) }
    func leavePost(id: String) async throws -> PostResponseAPIModel { try await leavePostHandler(id) }
    func closePost(id: String) async throws -> PostResponseAPIModel { try await closePostHandler(id) }
    func searchPosts(_ body: PostSearchRequestAPIModel) async throws -> PostSearchResponseAPIModel { try await searchPostsHandler(body) }
    func myPosts(cursor: String?) async throws -> PostPageResponseAPIModel { try await myPostsHandler(cursor) }
    func myParticipations(cursor: String?) async throws -> PostPageResponseAPIModel { try await myParticipationsHandler(cursor) }
}

@MainActor
final class MockCognitoAuthAPI: CognitoAuthAPI {
    var isSignedInHandler: () async throws -> Bool = { throw Unimplemented() }
    var signInHandler: (String, String) async throws -> AuthSignInResult = { _, _ in throw Unimplemented() }
    var signOutHandler: () async throws -> Void = { throw Unimplemented() }

    func isSignedIn() async throws -> Bool { try await isSignedInHandler() }
    func accessToken() async throws -> String { throw Unimplemented() }
    func signIn(email: String, password: String) async throws -> AuthSignInResult { try await signInHandler(email, password) }
    func signOut() async throws { try await signOutHandler() }
}

/// API の応答データ
enum APIFixture {
    static let author = ProfileResponseAPIModel(publicUserId: "u", displayName: "ユーザー", avatarVersion: 1)

    static func post(id: String, count: Int = 0) -> PostResponseAPIModel {
        PostResponseAPIModel(
            id: id, gameId: "g", body: "テスト用の募集本文です。よろしくお願いします。", vcTool: "discord",
            capacity: 3, participantCount: count, status: "open", isJoinedByMe: false, isOwnedByMe: false,
            createdAt: "2026-11-01T10:00:00Z", author: author
        )
    }

    static func error(_ status: Int, code: String, avatar: ErrorResponseAPIModel.PendingAvatar? = nil) -> HTTPErrorAPIModel {
        HTTPErrorAPIModel(statusCode: status, body: ErrorResponseAPIModel(error: .init(code: code, message: "m", pendingAvatar: avatar)))
    }
}
