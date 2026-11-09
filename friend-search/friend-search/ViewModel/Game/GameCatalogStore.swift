import Foundation
import Observation

/// アプリ全体で共有するゲームマスタ
@MainActor
@Observable
final class GameCatalogStore {
    /// 有効・無効を含むゲームマスタ。未取得なら nil
    private(set) var games: [Game]?
    private(set) var error: AppError?
    /// 実行中の取得。同時に呼ばれたら新しく取得せず、この完了を待つ
    private var loading: Task<Void, Never>?
    private var index: GameSearchIndex?

    private let getGames: any GetGamesUseCase

    init(getGames: any GetGamesUseCase = DefaultGetGamesUseCase()) {
        self.getGames = getGames
    }

    var isLoading: Bool { loading != nil }

    func loadIfNeeded() async {
        if games == nil || error != nil { await refresh() }
    }

    func refresh() async {
        if let loading {
            await loading.value
            return
        }
        // 画面を離れても取得は続け、共有するマスタを最後まで更新する
        let task = Task { await fetch() }
        loading = task
        await task.value
        loading = nil
    }

    func search(_ query: String) -> [Game] {
        index?.search(query) ?? []
    }

    /// マスタにない ID（未取得など）はそのまま表示する
    func displayName(for gameId: String) -> String {
        games?.first { $0.id == gameId }?.displayName ?? gameId
    }

    private func fetch() async {
        do {
            let games = try await getGames.execute()
            self.games = games
            index = GameSearchIndex(games: games)
            error = nil
        } catch {
            self.error = AppError(error: error)
        }
    }
}
