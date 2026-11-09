import Foundation

protocol CreatePostUseCase {
    /// 同じ clientRequestId の再送はサーバーが重複作成しない
    func execute(_ newPost: NewPost, clientRequestId: UUID) async throws -> Post
}

struct DefaultCreatePostUseCase: CreatePostUseCase {
    private let repository: any PostRepository

    init(repository: any PostRepository = DefaultPostRepository()) {
        self.repository = repository
    }

    func execute(_ newPost: NewPost, clientRequestId: UUID) async throws -> Post {
        try await repository.create(newPost, clientRequestId: clientRequestId)
    }
}
