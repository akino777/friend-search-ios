import Foundation

protocol GetPostUseCase {
    func execute(id: String) async throws -> Post
}

struct DefaultGetPostUseCase: GetPostUseCase {
    private let repository: any PostRepository

    init(repository: any PostRepository = DefaultPostRepository()) {
        self.repository = repository
    }

    func execute(id: String) async throws -> Post {
        try await repository.post(id: id)
    }
}
