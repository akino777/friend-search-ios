import Foundation

protocol SearchPostsUseCase {
    func execute(gameId: String?, query: String, vcTool: VCTool?) async throws -> [Post]
}

struct DefaultSearchPostsUseCase: SearchPostsUseCase {
    private let repository: any PostRepository

    init(repository: any PostRepository = DefaultPostRepository()) {
        self.repository = repository
    }

    func execute(gameId: String?, query: String, vcTool: VCTool?) async throws -> [Post] {
        try await repository.search(gameId: gameId, query: query, vcTool: vcTool)
    }
}
