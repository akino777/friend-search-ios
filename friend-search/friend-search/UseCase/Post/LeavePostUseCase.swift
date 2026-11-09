import Foundation

protocol LeavePostUseCase {
    func execute(postId: String) async throws -> Post
}

struct DefaultLeavePostUseCase: LeavePostUseCase {
    private let repository: any PostRepository

    init(repository: any PostRepository = DefaultPostRepository()) {
        self.repository = repository
    }

    func execute(postId: String) async throws -> Post {
        try await repository.leave(postId: postId)
    }
}
