import Foundation

// ViewModel 層のテストで差し込む UseCase のモック。未設定の処理は Unimplemented を投げる。

@MainActor
final class MockCreatePostUseCase: CreatePostUseCase {
    var handler: (NewPost, UUID) async throws -> Post = { _, _ in throw Unimplemented() }
    private(set) var received: [(draft: NewPost, requestId: UUID)] = []

    func execute(_ newPost: NewPost, clientRequestId: UUID) async throws -> Post {
        received.append((newPost, clientRequestId))
        return try await handler(newPost, clientRequestId)
    }
}

@MainActor
final class MockSearchPostsUseCase: SearchPostsUseCase {
    struct Request: Equatable {
        let gameId: String?
        let query: String
        let vcTool: VCTool?
    }

    var handler: (String) async throws -> [Post] = { _ in throw Unimplemented() }
    private(set) var requests: [Request] = []
    var queries: [String] { requests.map(\.query) }
    var calls: Int { requests.count }

    func execute(gameId: String?, query: String, vcTool: VCTool?) async throws -> [Post] {
        requests.append(Request(gameId: gameId, query: query, vcTool: vcTool))
        return try await handler(query)
    }
}

@MainActor
final class MockGetPostUseCase: GetPostUseCase {
    var handler: (String) async throws -> Post = { _ in throw Unimplemented() }
    private(set) var calls = 0

    func execute(id: String) async throws -> Post {
        calls += 1
        return try await handler(id)
    }
}

/// 参加・取消・終了（いずれも募集 ID を受け取り更新後の募集を返す）
@MainActor
final class MockPostActionUseCase: JoinPostUseCase, LeavePostUseCase, ClosePostUseCase {
    var handler: (String) async throws -> Post = { _ in throw Unimplemented() }

    func execute(postId: String) async throws -> Post { try await handler(postId) }
}

@MainActor
final class MockListPostsUseCase: ListPostsUseCase {
    var handler: (String?) async throws -> PostPage = { _ in throw Unimplemented() }
    private(set) var requestedGameIds: [String?] = []

    func execute(gameId: String?, cursor: String?) async throws -> PostPage {
        requestedGameIds.append(gameId)
        return try await handler(cursor)
    }
}

@MainActor
final class MockListMyPostsUseCase: ListMyPostsUseCase {
    var myPostsHandler: (String?) async throws -> PostPage = { _ in PostPage(items: [], nextCursor: nil) }
    var participationsHandler: (String?) async throws -> PostPage = { _ in PostPage(items: [], nextCursor: nil) }

    func myPosts(cursor: String?) async throws -> PostPage { try await myPostsHandler(cursor) }
    func participations(cursor: String?) async throws -> PostPage { try await participationsHandler(cursor) }
}

@MainActor
final class MockUpdateProfileUseCase: UpdateProfileUseCase {
    var handler: (String) async throws -> PublicProfile = { _ in throw Unimplemented() }
    private(set) var names: [String] = []

    func execute(displayName: String) async throws -> PublicProfile {
        names.append(displayName)
        return try await handler(displayName)
    }
}

@MainActor
final class MockRestoreSessionUseCase: RestoreSessionUseCase {
    var handler: () async throws -> Bool = { throw Unimplemented() }

    func execute() async throws -> Bool { try await handler() }
}

@MainActor
final class MockGetProfileUseCase: GetProfileUseCase {
    var handler: () async throws -> ProfileLookup = { throw Unimplemented() }

    func execute() async throws -> ProfileLookup { try await handler() }
}

@MainActor
final class MockSignOutUseCase: SignOutUseCase {
    private(set) var calls = 0

    func execute() async throws { calls += 1 }
}

@MainActor
final class MockGetGamesUseCase: GetGamesUseCase {
    var executeHandler: () async throws -> [Game] = { throw Unimplemented() }

    func execute() async throws -> [Game] { try await executeHandler() }
}

@MainActor
final class MockSignInUseCase: SignInUseCase {
    var handler: (String, String) async throws -> SignInOutcome = { _, _ in throw Unimplemented() }
    private(set) var emails: [String] = []

    func execute(email: String, password: String) async throws -> SignInOutcome {
        emails.append(email)
        return try await handler(email, password)
    }
}

@MainActor
final class MockBootstrapProfileUseCase: BootstrapProfileUseCase {
    var handler: (String) async throws -> PublicProfile = { _ in throw Unimplemented() }
    private(set) var names: [String] = []

    func execute(displayName: String) async throws -> PublicProfile {
        names.append(displayName)
        return try await handler(displayName)
    }
}
