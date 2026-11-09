import Foundation

protocol ListMyPostsUseCase {
    func myPosts(cursor: String?) async throws -> PostPage
    func participations(cursor: String?) async throws -> PostPage
}

struct DefaultListMyPostsUseCase: ListMyPostsUseCase {
    private let repository: any PostRepository

    init(repository: any PostRepository = DefaultPostRepository()) {
        self.repository = repository
    }

    func myPosts(cursor: String?) async throws -> PostPage {
        try await repository.myPosts(cursor: cursor)
    }

    func participations(cursor: String?) async throws -> PostPage {
        try await repository.myParticipations(cursor: cursor)
    }
}
