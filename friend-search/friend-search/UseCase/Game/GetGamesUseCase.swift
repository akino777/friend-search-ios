import Foundation

protocol GetGamesUseCase {
    func execute() async throws -> [Game]
}

struct DefaultGetGamesUseCase: GetGamesUseCase {
    private let repository: any GameRepository

    init(repository: any GameRepository = DefaultGameRepository()) {
        self.repository = repository
    }

    func execute() async throws -> [Game] {
        try await repository.games()
    }
}
