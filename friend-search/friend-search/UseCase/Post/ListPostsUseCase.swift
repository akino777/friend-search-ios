import Foundation

protocol ListPostsUseCase {
    /// gameId が nil なら全ゲームの新着
    func execute(gameId: String?, cursor: String?) async throws -> PostPage
}

struct DefaultListPostsUseCase: ListPostsUseCase {
    private let repository: any PostRepository

    init(repository: any PostRepository = DefaultPostRepository()) {
        self.repository = repository
    }

    func execute(gameId: String?, cursor: String?) async throws -> PostPage {
        try await repository.listPosts(gameId: gameId, cursor: cursor)
    }
}
