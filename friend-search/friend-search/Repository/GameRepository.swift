import Foundation

protocol GameRepository {
    func games() async throws -> [Game]
}

final class DefaultGameRepository: GameRepository {
    private let api: any FriendSearchAPI

    init(api: any FriendSearchAPI = DefaultFriendSearchAPI()) {
        self.api = api
    }

    func games() async throws -> [Game] {
        try await withAppErrors { try await api.fetchGames().games.map(Game.init(apiModel:)) }
    }
}
