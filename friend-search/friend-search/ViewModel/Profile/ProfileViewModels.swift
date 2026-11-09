import Foundation
import Observation

/// 初回の表示名設定
@MainActor
@Observable
final class ProfileSetupViewModel {
    var displayName = ""
    private(set) var isSubmitting = false
    var errorMessage: String?

    private let bootstrap: any BootstrapProfileUseCase

    init(bootstrap: any BootstrapProfileUseCase = DefaultBootstrapProfileUseCase()) {
        self.bootstrap = bootstrap
    }

    var canSubmit: Bool { DisplayNameRule.normalized(displayName) != nil && !isSubmitting }

    func submit() async -> PublicProfile? {
        guard !isSubmitting else { return nil }
        guard let name = DisplayNameRule.normalized(displayName) else {
            errorMessage = DisplayNameRule.invalidMessage
            return nil
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            return try await bootstrap.execute(displayName: name)
        } catch {
            errorMessage = AppError(error: error).message
            return nil
        }
    }
}

/// マイページ（自分の募集・参加中の募集・表示名変更）
@MainActor
@Observable
final class MyPageViewModel {
    enum Segment: String, CaseIterable, Identifiable {
        case myPosts = "自分の募集"
        case participations = "参加中"
        var id: String { rawValue }
    }

    private(set) var profile: PublicProfile
    var segment: Segment = .myPosts
    private(set) var phase: ListPhase = .idle
    private var pagers: [Segment: PostPager] = [:]
    var editingName = ""
    private(set) var isSavingName = false
    var nameError: String?

    /// 取り直しのたびに進める。それより前に始めた取得の結果は古いので捨てる
    private var generation = 0

    private let listMyPosts: any ListMyPostsUseCase
    private let updateProfile: any UpdateProfileUseCase
    private let onProfileUpdated: (PublicProfile) -> Void

    init(
        profile: PublicProfile,
        listMyPosts: any ListMyPostsUseCase = DefaultListMyPostsUseCase(),
        updateProfile: any UpdateProfileUseCase = DefaultUpdateProfileUseCase(),
        onProfileUpdated: @escaping (PublicProfile) -> Void = { _ in }
    ) {
        self.profile = profile
        self.listMyPosts = listMyPosts
        self.updateProfile = updateProfile
        self.onProfileUpdated = onProfileUpdated
    }

    var visiblePosts: [Post] { pagers[segment]?.posts ?? [] }
    var emptyMessage: String { segment == .myPosts ? "まだ募集を投稿していません" : "参加中の募集はありません" }
    var isLoadingMore: Bool { pagers[segment]?.isLoadingMore ?? false }
    var loadMoreError: AppError? { pagers[segment]?.loadMoreError }

    /// 表示のたびに呼び、自分の募集と参加中の募集を先頭から取り直す
    func reload() async {
        generation += 1
        let current = generation
        if visiblePosts.isEmpty { phase = .loading }
        do {
            async let postsPage = fetch(.myPosts, from: nil)
            async let joinedPage = fetch(.participations, from: nil)
            let (posts, joined) = try await (postsPage, joinedPage)
            guard current == generation else { return }
            pagers[.myPosts, default: PostPager()].reset(with: posts)
            pagers[.participations, default: PostPager()].reset(with: joined)
            phase = visiblePosts.isEmpty ? .empty : .loaded
        } catch is CancellationError {
        } catch {
            guard current == generation else { return }
            phase = .failed(AppError(error: error))
        }
    }

    func segmentChanged() {
        if case .failed = phase { return }
        phase = visiblePosts.isEmpty ? .empty : .loaded
    }

    /// 一覧の末尾が表示されたら次ページを読み込む
    func loadMoreIfNeeded(current post: Post) async {
        guard post.id == visiblePosts.last?.id, loadMoreError == nil else { return }
        await loadMore()
    }

    /// 追加読み込みの失敗は読み込み済みの一覧を壊さず、カーソルを残して再試行できるようにする
    func loadMore() async {
        let target = segment
        guard let pager = pagers[target], let cursor = pager.nextCursor, !pager.isLoadingMore else { return }
        let current = generation
        pagers[target]?.isLoadingMore = true
        pagers[target]?.loadMoreError = nil
        defer { pagers[target]?.isLoadingMore = false }
        do {
            let page = try await fetch(target, from: cursor)
            guard current == generation else { return }
            pagers[target]?.append(page)
        } catch is CancellationError {
        } catch {
            guard current == generation else { return }
            pagers[target]?.loadMoreError = AppError(error: error)
        }
    }

    private func fetch(_ segment: Segment, from cursor: String?) async throws -> PostPage {
        try await PostPager.fetch(from: cursor) { [listMyPosts] cursor in
            switch segment {
            case .myPosts: try await listMyPosts.myPosts(cursor: cursor)
            case .participations: try await listMyPosts.participations(cursor: cursor)
            }
        }
    }

    var canSaveName: Bool { DisplayNameRule.normalized(editingName) != nil && !isSavingName }

    func beginEditingName() {
        editingName = profile.displayName
        nameError = nil
    }

    func saveName() async -> Bool {
        guard !isSavingName else { return false }
        guard let name = DisplayNameRule.normalized(editingName) else {
            nameError = DisplayNameRule.invalidMessage
            return false
        }
        isSavingName = true
        nameError = nil
        defer { isSavingName = false }
        do {
            profile = try await updateProfile.execute(displayName: name)
            onProfileUpdated(profile)
            return true
        } catch {
            nameError = AppError(error: error).message
            return false
        }
    }
}
