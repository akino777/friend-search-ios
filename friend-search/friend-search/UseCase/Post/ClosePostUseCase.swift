import Foundation

protocol ClosePostUseCase {
    func execute(postId: String) async throws -> Post
}

struct DefaultClosePostUseCase: ClosePostUseCase {
    private let repository: any PostRepository

    init(repository: any PostRepository = DefaultPostRepository()) {
        self.repository = repository
    }

    func execute(postId: String) async throws -> Post {
        try await repository.close(postId: postId)
    }
}
