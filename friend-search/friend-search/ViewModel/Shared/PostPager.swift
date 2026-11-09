import Foundation

/// カーソルページングの一覧の状態。次ページは重複を除いて追記する
struct PostPager {
    static let maxEmptyPages = 5

    private(set) var posts: [Post] = []
    private(set) var nextCursor: String?
    var isLoadingMore = false
    var loadMoreError: AppError?

    mutating func reset(with page: PostPage) {
        posts = page.items
        nextCursor = page.nextCursor
        loadMoreError = nil
    }

    mutating func append(_ page: PostPage) {
        let known = Set(posts.map(\.id))
        posts += page.items.filter { !known.contains($0.id) }
        nextCursor = page.nextCursor
    }

    /// 1ページ取得する。空ページでも続きがある場合は、画面の末尾表示を待たずに次のページまで進む
    static func fetch(from cursor: String?, using request: (String?) async throws -> PostPage) async throws -> PostPage {
        var page = try await request(cursor)
        for _ in 0..<maxEmptyPages {
            guard page.items.isEmpty, let next = page.nextCursor else { break }
            page = try await request(next)
        }
        return page
    }
}
