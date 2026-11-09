import Foundation

protocol JoinPostUseCase {
    func execute(postId: String) async throws -> Post
}

struct DefaultJoinPostUseCase: JoinPostUseCase {
    private let repository: any PostRepository

    init(repository: any PostRepository = DefaultPostRepository()) {
        self.repository = repository
    }

    func execute(postId: String) async throws -> Post {
        try await repository.join(postId: postId)
    }
}
