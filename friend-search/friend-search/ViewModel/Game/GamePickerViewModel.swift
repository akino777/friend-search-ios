import Foundation
import Observation

/// ゲーム選択（端末内のマスタから候補を出す）
@MainActor
@Observable
final class GamePickerViewModel {
    var query = ""
    let store: GameCatalogStore

    init(store: GameCatalogStore) {
        self.store = store
    }

    var candidates: [Game] { store.search(query) }

    /// マスタを読み込めていて、入力があるのに候補が0件か
    var showsNoMatch: Bool {
        store.games != nil && !query.trimmingCharacters(in: .whitespaces).isEmpty && candidates.isEmpty
    }

    func load() async {
        await store.loadIfNeeded()
    }
}
