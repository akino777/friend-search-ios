import Foundation

nonisolated struct GameCatalogAPIModel: Decodable, Sendable {
    let games: [GameAPIModel]
}

nonisolated struct GameAPIModel: Decodable, Sendable {
    let id: String
    let displayName: String
    let aliases: [String]
    let active: Bool
}
