import Foundation

nonisolated struct Game: Identifiable, Sendable, Equatable, Hashable {
    /// 永続識別子（表示名が変わっても変わらない）
    let id: String
    let displayName: String
    let aliases: [String]
    let isActive: Bool
}

// MARK: - APIModel → Model

nonisolated extension Game {
    init(apiModel: GameAPIModel) {
        self.init(id: apiModel.id, displayName: apiModel.displayName, aliases: apiModel.aliases, isActive: apiModel.active)
    }
}
