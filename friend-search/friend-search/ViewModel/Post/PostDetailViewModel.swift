import Foundation
import Observation

/// 募集詳細（参加・取消・投稿者による終了）
@MainActor
@Observable
final class PostDetailViewModel {
    let postId: String
    private(set) var post: Post?
    private(set) var loadError: AppError?
    private(set) var isProcessing = false
    var actionMessage: String?
    /// 募集が削除された・存在しない場合に画面を閉じる
    private(set) var shouldDismiss = false

    /// 取得や操作を始めるたびに進める。それより前に始めた取得の結果は古いので捨てる
    private var generation = 0
    private let getPost: any GetPostUseCase
    private let joinPost: any JoinPostUseCase
    private let leavePost: any LeavePostUseCase
    private let closePost: any ClosePostUseCase
    /// 最新の募集を呼び出し元へ伝える（AI 検索の結果に反映する）
    private let onUpdate: (Post) -> Void

    init(
        postId: String,
        initialPost: Post?,
        getPost: any GetPostUseCase = DefaultGetPostUseCase(),
        joinPost: any JoinPostUseCase = DefaultJoinPostUseCase(),
        leavePost: any LeavePostUseCase = DefaultLeavePostUseCase(),
        closePost: any ClosePostUseCase = DefaultClosePostUseCase(),
        onUpdate: @escaping (Post) -> Void = { _ in }
    ) {
        self.postId = postId
        self.post = initialPost
        self.getPost = getPost
        self.joinPost = joinPost
        self.leavePost = leavePost
        self.closePost = closePost
        self.onUpdate = onUpdate
    }

    func load() async {
        generation += 1
        let current = generation
        do {
            let latest = try await getPost.execute(id: postId)
            guard current == generation else { return }
            show(latest)
            loadError = nil
        } catch is CancellationError {
        } catch {
            guard current == generation else { return }
            switch AppError(error: error) {
            case .notFound: shouldDismiss = true
            case let appError: loadError = appError
            }
        }
    }

    func join() async { await perform { try await $0.joinPost.execute(postId: $0.postId) } }
    func leave() async { await perform { try await $0.leavePost.execute(postId: $0.postId) } }
    func close() async { await perform { try await $0.closePost.execute(postId: $0.postId) } }

    /// 成功する前に確定した表示をしない。失敗したら理由を出し、必要なら最新状態を取り直す
    private func perform(_ operation: (PostDetailViewModel) async throws -> Post) async {
        guard !isProcessing else { return }
        isProcessing = true
        actionMessage = nil
        defer { isProcessing = false }
        do {
            let updated = try await operation(self)
            // 操作の前に始めた取得の結果で、操作後の状態を上書きしない
            generation += 1
            show(updated)
        } catch {
            let appError = AppError(error: error)
            if appError == .notFound {
                shouldDismiss = true
                return
            }
            actionMessage = appError.message
            if Self.needsReload(after: appError) { await load() }
        }
    }

    private func show(_ latest: Post) {
        post = latest
        onUpdate(latest)
    }

    /// 失敗後に最新状態を取り直すべきか（競合・状態変化・一時的な障害）
    private static func needsReload(after error: AppError) -> Bool {
        switch error {
        case .postFull, .postClosed, .concurrentUpdate, .forbidden, .network, .temporarilyUnavailable: true
        default: false
        }
    }
}
