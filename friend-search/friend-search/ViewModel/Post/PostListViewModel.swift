import Foundation
import Observation

/// 募集一覧（新着順・カーソルページング）と AI 検索。未選択なら全ゲーム、ゲームを選ぶとそのゲームに絞り込む。
/// AI 検索中・検索結果の表示中は、新着の代わりに検索結果を出す（検索ボタン押下で実行し、キーストローク単位では呼ばない）
@MainActor
@Observable
final class PostListViewModel {
    /// AI 検索の状態。idle のときは新着を出す
    enum SearchPhase: Equatable {
        case idle
        case searching
        case results
        case empty
        /// AI 検索が使えない
        case unavailable
        case failed(AppError)
    }

    /// 検索条件。同じ条件の重複実行を見分けるのに使う
    private struct SearchRequest: Equatable {
        let gameId: String?
        let query: String
        let vcTool: VCTool?
    }

    /// 同じ条件の再検索を抑止する時間（Bedrock の呼び出しを減らす）
    static let duplicateSearchInterval: TimeInterval = 5

    /// 絞り込み中のゲーム。nil なら全ゲーム
    private(set) var selectedGameId: String?
    private(set) var phase: ListPhase = .idle
    private(set) var pager = PostPager()
    private(set) var searchPhase: SearchPhase = .idle
    private(set) var searchResults: [Post] = []

    private let listPosts: any ListPostsUseCase
    private let searchPosts: any SearchPostsUseCase
    private let now: () -> Date
    /// 取り直しのたびに進める。それより前に始めた取得の結果は古いので捨てる
    private var loadGeneration = 0
    /// 検索の開始・解除のたびに進める。それより前に始めた検索の結果は古いので捨てる
    private var searchGeneration = 0
    private var lastSearch: SearchRequest?
    private var lastSearchCompletedAt: Date?

    init(
        listPosts: any ListPostsUseCase = DefaultListPostsUseCase(),
        searchPosts: any SearchPostsUseCase = DefaultSearchPostsUseCase(),
        now: @escaping () -> Date = Date.init
    ) {
        self.listPosts = listPosts
        self.searchPosts = searchPosts
        self.now = now
    }

    var posts: [Post] { pager.posts }
    var isLoadingMore: Bool { pager.isLoadingMore }

    /// 検索中・検索結果の表示中か（新着の代わりに検索結果を出す）
    var isSearchActive: Bool { searchPhase != .idle }

    var searchErrorMessage: String? {
        switch searchPhase {
        case .unavailable: AppError.searchUnavailable.message
        case .failed(let error): error.message
        default: nil
        }
    }

    /// 絞り込むゲームを変える。nil で解除（全ゲーム）。検索結果の表示中なら、同じ検索文で選んだゲームを検索し直す
    func select(gameId: String?) async {
        guard gameId != selectedGameId else { return }
        selectedGameId = gameId
        pager = PostPager()
        if isSearchActive {
            async let list: Void = reload()
            async let search: Void = searchAgain()
            _ = await (list, search)
        } else {
            await reload()
        }
    }

    /// 表示のたびに呼び、絞り込み中の条件で募集を先頭から取り直す（AI 検索は費用がかかるので取り直さない）
    func reload() async {
        let gameId = selectedGameId
        if posts.isEmpty { phase = .loading }
        loadGeneration += 1
        let generation = loadGeneration
        do {
            let page = try await fetch(gameId: gameId, from: nil)
            guard generation == loadGeneration else { return }
            pager.reset(with: page)
            phase = posts.isEmpty ? .empty : .loaded
        } catch is CancellationError {
        } catch {
            guard generation == loadGeneration else { return }
            phase = .failed(AppError(error: error))
        }
    }

    /// 引っ張って更新。検索結果の表示中は同じ条件で検索し直し、それ以外は新着を取り直す
    func refresh() async {
        if isSearchActive {
            await searchAgain()
        } else {
            await reload()
        }
    }

    /// 一覧の末尾が表示されたら次ページを読み込む。失敗しても読み込み済みの一覧は壊さない
    func loadMoreIfNeeded(current post: Post) async {
        guard post.id == posts.last?.id, let cursor = pager.nextCursor, !pager.isLoadingMore else { return }
        let gameId = selectedGameId
        pager.isLoadingMore = true
        defer { pager.isLoadingMore = false }
        let generation = loadGeneration
        do {
            let page = try await fetch(gameId: gameId, from: cursor)
            guard generation == loadGeneration else { return }
            pager.append(page)
        } catch {
            // 次に末尾が表示されたときに再試行する
        }
    }

    /// 絞り込み中のゲーム（未選択なら全ゲーム）を AI 検索する。検索文が規則を満たさなければ何もしない
    func search(query: String, vcTool: VCTool?) async {
        guard let normalizedQuery = PostInputRule.normalizedQuery(query) else { return }
        await runSearch(SearchRequest(gameId: selectedGameId, query: normalizedQuery, vcTool: vcTool))
    }

    /// 検索を解除して新着に戻る。通信中の検索の結果は捨てる
    func clearSearch() {
        searchGeneration += 1
        lastSearch = nil
        lastSearchCompletedAt = nil
        searchResults = []
        searchPhase = .idle
    }

    /// 詳細画面で更新された募集を検索結果に反映する（検索は費用がかかるので取り直さない）
    func applyToSearchResults(_ post: Post) {
        if let index = searchResults.firstIndex(where: { $0.id == post.id }) { searchResults[index] = post }
    }

    /// 直前の検索と同じ検索文・VC で、絞り込み中のゲームを検索し直す
    private func searchAgain() async {
        guard let lastSearch else { return }
        await runSearch(SearchRequest(gameId: selectedGameId, query: lastSearch.query, vcTool: lastSearch.vcTool))
    }

    private func runSearch(_ request: SearchRequest) async {
        if request == lastSearch, isDuplicateSearch { return }

        searchGeneration += 1
        let current = searchGeneration
        lastSearch = request
        lastSearchCompletedAt = nil
        searchPhase = .searching
        do {
            let posts = try await searchPosts.execute(gameId: request.gameId, query: request.query, vcTool: request.vcTool)
            guard current == searchGeneration else { return }
            searchResults = posts
            searchPhase = posts.isEmpty ? .empty : .results
            lastSearchCompletedAt = now()
        } catch is CancellationError {
            // 取り消された。「検索中」のまま止まらないよう、検索を解除した状態に戻す
            guard current == searchGeneration else { return }
            clearSearch()
        } catch {
            guard current == searchGeneration else { return }
            searchResults = []
            switch AppError(error: error) {
            case .searchUnavailable, .temporarilyUnavailable: searchPhase = .unavailable
            case let appError: searchPhase = .failed(appError)
            }
        }
    }

    /// 同じ条件が通信中、または直前に完了したばかりか（取り消してもサーバー側の処理と回数制限は消費され得る）
    private var isDuplicateSearch: Bool {
        switch searchPhase {
        case .searching:
            return true
        case .results, .empty:
            guard let lastSearchCompletedAt else { return false }
            return now().timeIntervalSince(lastSearchCompletedAt) < Self.duplicateSearchInterval
        default:
            return false
        }
    }

    private func fetch(gameId: String?, from cursor: String?) async throws -> PostPage {
        try await PostPager.fetch(from: cursor) { [listPosts] in
            try await listPosts.execute(gameId: gameId, cursor: $0)
        }
    }
}
