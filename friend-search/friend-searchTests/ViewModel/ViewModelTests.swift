import Foundation
import Testing

// ViewModel 層: 画面状態・多重実行の抑止・古い結果の破棄。依存は UseCase のモックのみ。
// 「通信中」「後から応答が届く」状況は Gate で作り、時間待ちには頼らない。

@MainActor
struct CreatePostViewModelTests {
    let useCase = MockCreatePostUseCase()
    let game = Game(id: "monster-hunter-wilds", displayName: "モンハンワイルズ", aliases: [], isActive: true)
    let body = "今夜、初心者同士でまったり狩りたい。ミスしてもOKな人！"

    func make() -> CreatePostViewModel {
        let viewModel = CreatePostViewModel(createPost: useCase)
        viewModel.selectedGame = game
        viewModel.body = body
        return viewModel
    }

    @Test func 入力を整えた募集内容で送信する() async {
        useCase.handler = { _, id in Fixture.post(id: id.uuidString) }
        let viewModel = make()
        viewModel.body = "  \(body)\n"
        viewModel.vcTool = .discord
        viewModel.inviteUrl = " https://discord.gg/abc "
        viewModel.updateCapacityText("3")
        #expect(await viewModel.submit() != nil)
        #expect(useCase.received.first?.draft == NewPost(
            gameId: game.id, body: body, vcTool: .discord, capacity: 3, inviteUrl: "https://discord.gg/abc"
        ))
    }

    @Test func 結果不明の再送は同じclientRequestIdを使い内容を変えたら新しいIDにする() async {
        useCase.handler = { _, _ in throw AppError.network }
        let viewModel = make()
        _ = await viewModel.submit()
        _ = await viewModel.submit()
        viewModel.updateCapacityText("3")
        _ = await viewModel.submit()
        let ids = useCase.received.map(\.requestId)
        #expect(ids.count == 3)
        #expect(ids[0] == ids[1])
        #expect(ids[1] != ids[2])
        #expect(viewModel.errorMessage == AppError.network.message)
    }

    @Test func 投稿中の多重タップは送信しない() async {
        let gate = Gate()
        useCase.handler = { _, id in
            await gate.pass()
            return Fixture.post(id: id.uuidString)
        }
        let viewModel = make()
        let first = Task { await viewModel.submit() }
        await gate.waitForArrival()
        #expect(viewModel.isSubmitting)
        #expect(await viewModel.submit() == nil)
        gate.open()
        #expect(await first.value != nil)
        #expect(useCase.received.count == 1)
    }

    @Test func 投稿に成功したら入力を初期状態に戻す() async {
        useCase.handler = { _, id in Fixture.post(id: id.uuidString) }
        let viewModel = make()
        viewModel.vcTool = .discord
        viewModel.inviteUrl = "https://discord.gg/abc"
        viewModel.updateCapacityText("5")
        #expect(await viewModel.submit() != nil)
        #expect(viewModel.body.isEmpty)
        #expect(viewModel.vcTool == .none)
        #expect(viewModel.inviteUrl.isEmpty)
        #expect(viewModel.capacityText == String(PostInputRule.defaultCapacity))
    }

    @Test func ゲーム未選択は送信しない() async {
        let viewModel = make()
        viewModel.selectedGame = nil
        #expect(!viewModel.canSubmit)
        #expect(await viewModel.submit() == nil)
        #expect(viewModel.errorMessage == PostInputRule.gameMissingMessage)
        #expect(useCase.received.isEmpty)
    }

    @Test(arguments: [" \n ", String(repeating: "あ", count: 1001)])
    func 本文の文字数が範囲外なら送信しない(text: String) async {
        let viewModel = make()
        viewModel.body = text
        #expect(!viewModel.isBodyCountValid)
        #expect(await viewModel.submit() == nil)
        #expect(viewModel.errorMessage == PostInputRule.bodyMessage)
    }

    @Test func 本文は前後の空白を除いて1文字から送信できる() async {
        useCase.handler = { _, id in Fixture.post(id: id.uuidString) }
        let viewModel = make()
        viewModel.body = " あ "
        #expect(viewModel.canSubmit)
        #expect(await viewModel.submit() != nil)
        #expect(useCase.received.first?.draft.body == "あ")
    }

    @Test(arguments: ["http://discord.gg/abc", "https://evil.example.com/abc", "https://user@discord.gg/abc", "https://discord.gg:8443/abc", ""])
    func ツールの公式ホストのHTTPS以外の招待リンクは送信しない(link: String) async {
        let viewModel = make()
        viewModel.vcTool = .discord
        viewModel.inviteUrl = link
        #expect(await viewModel.submit() == nil)
        #expect(viewModel.errorMessage == PostInputRule.inviteLinkMessage)
        #expect(useCase.received.isEmpty)
    }

    @Test func 招待リンクを扱わないツールではリンクを送らない() async {
        useCase.handler = { _, id in Fixture.post(id: id.uuidString) }
        let viewModel = make()
        viewModel.vcTool = .inGame
        viewModel.inviteUrl = "https://discord.gg/abc"
        _ = await viewModel.submit()
        #expect(useCase.received.first?.draft.inviteUrl == nil)
    }

    @Test func 募集人数の入力欄は半角数字2桁だけ残す() {
        let viewModel = make()
        viewModel.updateCapacityText("1a2b3")
        #expect(viewModel.capacityText == "12")
        #expect(viewModel.capacity == nil)
        #expect(viewModel.capacityError == PostInputRule.capacityMessage)
        viewModel.updateCapacityText("5")
        #expect(viewModel.capacity == 5)
        viewModel.updateCapacityText("１")
        #expect(viewModel.capacityText.isEmpty)
    }
}

@MainActor
struct PostDetailViewModelTests {
    let getPost = MockGetPostUseCase()
    let join = MockPostActionUseCase()

    func make(initialPost: Post? = Fixture.post(id: "p"), onUpdate: @escaping (Post) -> Void = { _ in }) -> PostDetailViewModel {
        PostDetailViewModel(
            postId: "p", initialPost: initialPost,
            getPost: getPost, joinPost: join, leavePost: MockPostActionUseCase(), closePost: MockPostActionUseCase(),
            onUpdate: onUpdate
        )
    }

    @Test func 満員の409は説明を出して最新状態を取り直す() async {
        join.handler = { _ in throw AppError.postFull }
        getPost.handler = { _ in Fixture.post(id: "p", count: 3) }
        let viewModel = make()
        await viewModel.join()
        #expect(viewModel.actionMessage == AppError.postFull.message)
        #expect(viewModel.post?.participantCount == 3)
        #expect(getPost.calls == 1)
    }

    @Test func 参加成功で人数と参加状態を反映し呼び出し元へ伝える() async {
        join.handler = { _ in Fixture.post(id: "p", count: 1, joined: true) }
        var updated: Post?
        let viewModel = make(onUpdate: { updated = $0 })
        await viewModel.join()
        #expect(viewModel.post?.isJoinedByMe == true)
        #expect(viewModel.post?.participantCount == 1)
        #expect(viewModel.actionMessage == nil)
        #expect(updated?.isJoinedByMe == true)
    }

    @Test func 存在しない募集は画面を閉じる() async {
        getPost.handler = { _ in throw AppError.notFound }
        let viewModel = make(initialPost: nil)
        await viewModel.load()
        #expect(viewModel.shouldDismiss)
    }

    @Test func 参加後に古い詳細の取得結果で上書きしない() async {
        let gate = Gate()
        getPost.handler = { _ in
            await gate.pass()
            return Fixture.post(id: "p")
        }
        join.handler = { _ in Fixture.post(id: "p", count: 1, joined: true) }
        let viewModel = make()
        let loading = Task { await viewModel.load() }
        await gate.waitForArrival()
        await viewModel.join()
        gate.open()
        await loading.value
        #expect(viewModel.post?.isJoinedByMe == true)
    }

    @Test func 重なった取得では後から始めた結果を残す() async {
        let gate = Gate()
        var calls = 0
        getPost.handler = { _ in
            calls += 1
            if calls == 1 {
                await gate.pass()
                return Fixture.post(id: "p", count: 0)
            }
            return Fixture.post(id: "p", count: 2)
        }
        let viewModel = make()
        let older = Task { await viewModel.load() }
        await gate.waitForArrival()
        await viewModel.load()
        gate.open()
        await older.value
        #expect(viewModel.post?.participantCount == 2)
    }
}

@MainActor
struct RootViewModelTests {
    let restoreSession = MockRestoreSessionUseCase()
    let getProfile = MockGetProfileUseCase()

    func make() -> RootViewModel {
        RootViewModel(restoreSession: restoreSession, getProfile: getProfile, signOut: MockSignOutUseCase())
    }

    @Test func 未作成なら表示名設定へ() async {
        restoreSession.handler = { true }
        getProfile.handler = { .notCreated() }
        let viewModel = make()
        await viewModel.start()
        #expect(viewModel.state == .needsProfile(avatar: nil))
    }

    @Test func 未作成でもサーバーが返したアイコン情報を表示名設定へ渡す() async {
        let avatar = AvatarIdentity(publicUserId: "u1", avatarVersion: 1)
        restoreSession.handler = { true }
        getProfile.handler = { .notCreated(avatar: avatar) }
        let viewModel = make()
        await viewModel.start()
        #expect(viewModel.state == .needsProfile(avatar: avatar))
    }

    @Test func プロフィール取得の通信障害は未作成と区別する() async {
        restoreSession.handler = { true }
        getProfile.handler = { throw AppError.network }
        let viewModel = make()
        await viewModel.start()
        #expect(viewModel.state == .profileLoadFailed(.network))
    }

    @Test func 未ログインはログイン画面() async {
        restoreSession.handler = { false }
        let viewModel = make()
        await viewModel.start()
        #expect(viewModel.state == .signedOut(message: nil))
    }

    @Test func 起動時の通信障害はログイン画面へ戻さず再試行で復帰できる() async {
        restoreSession.handler = { throw AppError.network }
        getProfile.handler = { .notCreated() }
        let viewModel = make()
        await viewModel.start()
        #expect(viewModel.state == .profileLoadFailed(.network))
        await viewModel.loadProfile()
        #expect(viewModel.state == .needsProfile(avatar: nil))
    }

    @Test func 起動時の通信障害以外のエラーはログイン画面() async {
        restoreSession.handler = { throw AppError.unauthorized }
        let viewModel = make()
        await viewModel.start()
        #expect(viewModel.state == .signedOut(message: nil))
    }
}

@MainActor
struct MyPageViewModelTests {
    let listMyPosts = MockListMyPostsUseCase()

    func make() -> MyPageViewModel {
        MyPageViewModel(profile: Fixture.author, listMyPosts: listMyPosts, updateProfile: MockUpdateProfileUseCase())
    }

    @Test func 自分の募集を重複なく次ページまで表示する() async {
        listMyPosts.myPostsHandler = { $0 == nil ? Fixture.page(["a", "b"], next: "c1") : Fixture.page(["b", "c"]) }
        let viewModel = make()
        await viewModel.reload()
        await viewModel.loadMoreIfNeeded(current: viewModel.visiblePosts[0])
        #expect(viewModel.visiblePosts.map(\.id) == ["a", "b"])
        await viewModel.loadMoreIfNeeded(current: viewModel.visiblePosts[1])
        #expect(viewModel.visiblePosts.map(\.id) == ["a", "b", "c"])
    }

    @Test func 参加中も独立したカーソルで次ページを読む() async {
        listMyPosts.myPostsHandler = { _ in Fixture.page(["mine"]) }
        listMyPosts.participationsHandler = { $0 == nil ? Fixture.page(["j1"], next: "c1") : Fixture.page(["j2"]) }
        let viewModel = make()
        await viewModel.reload()
        viewModel.segment = .participations
        await viewModel.loadMoreIfNeeded(current: viewModel.visiblePosts[0])
        #expect(viewModel.visiblePosts.map(\.id) == ["j1", "j2"])
        viewModel.segment = .myPosts
        #expect(viewModel.visiblePosts.map(\.id) == ["mine"])
    }

    @Test func 空ページでも続きがあれば先へ進む() async {
        listMyPosts.myPostsHandler = { cursor in
            switch cursor {
            case nil: Fixture.page([], next: "c1")
            case "c1": Fixture.page(["a"], next: "c2")
            case "c2": Fixture.page([], next: "c3")
            default: Fixture.page(["b"])
            }
        }
        let viewModel = make()
        await viewModel.reload()
        #expect(viewModel.phase == .loaded)
        await viewModel.loadMore()
        #expect(viewModel.visiblePosts.map(\.id) == ["a", "b"])
    }

    @Test func 追加読み込みの失敗は一覧を保持して再試行できる() async {
        var fails = true
        listMyPosts.myPostsHandler = { cursor in
            guard cursor != nil else { return Fixture.page(["a"], next: "c1") }
            if fails { throw AppError.network }
            return Fixture.page(["b"])
        }
        let viewModel = make()
        await viewModel.reload()
        await viewModel.loadMoreIfNeeded(current: viewModel.visiblePosts[0])
        #expect(viewModel.loadMoreError == .network)
        #expect(viewModel.visiblePosts.map(\.id) == ["a"])
        fails = false
        await viewModel.loadMore()
        #expect(viewModel.loadMoreError == nil)
        #expect(viewModel.visiblePosts.map(\.id) == ["a", "b"])
    }

    @Test func 表示のたびに先頭から取り直す() async {
        var requested: [String?] = []
        listMyPosts.myPostsHandler = { cursor in
            requested.append(cursor)
            return cursor == nil ? Fixture.page(["a"], next: "c1") : Fixture.page(["b"])
        }
        let viewModel = make()
        await viewModel.reload()
        await viewModel.loadMore()
        await viewModel.reload()
        #expect(viewModel.visiblePosts.map(\.id) == ["a"])
        #expect(requested == [nil, "c1", nil])
    }
}

@MainActor
struct PostListViewModelTests {
    typealias SearchRequest = MockSearchPostsUseCase.Request

    let listUseCase = MockListPostsUseCase()
    let searchUseCase = MockSearchPostsUseCase()

    func make(now: @escaping () -> Date = Date.init) -> PostListViewModel {
        PostListViewModel(listPosts: listUseCase, searchPosts: searchUseCase, now: now)
    }

    // MARK: 新着

    @Test func 最初は全ゲームの新着を表示し末尾で続きを読み込む() async {
        listUseCase.handler = { cursor in cursor == nil ? Fixture.page(["p1"], next: "c1") : Fixture.page(["p2"]) }
        let viewModel = make()
        #expect(viewModel.selectedGameId == nil)
        await viewModel.reload()
        await viewModel.loadMoreIfNeeded(current: viewModel.posts[0])
        #expect(viewModel.posts.map(\.id) == ["p1", "p2"])
        #expect(listUseCase.requestedGameIds == [nil, nil])
    }

    @Test func ゲームで絞り込み解除すると全ゲームに戻る() async {
        listUseCase.handler = { _ in Fixture.page(["p"]) }
        let viewModel = make()
        await viewModel.reload()
        await viewModel.select(gameId: "apex-legends")
        #expect(viewModel.selectedGameId == "apex-legends")
        await viewModel.select(gameId: nil)
        #expect(viewModel.selectedGameId == nil)
        #expect(listUseCase.requestedGameIds == [nil, "apex-legends", nil])
    }

    @Test func 更新後に古い次ページの結果を混ぜない() async {
        let gate = Gate()
        var refreshed = false
        listUseCase.handler = { cursor in
            if cursor != nil {
                await gate.pass()
                return Fixture.page(["old"], next: "c-old")
            }
            return refreshed ? Fixture.page(["fresh"]) : Fixture.page(["first"], next: "c1")
        }
        let viewModel = make()
        await viewModel.reload()
        let more = Task { await viewModel.loadMoreIfNeeded(current: viewModel.posts[0]) }
        await gate.waitForArrival()
        refreshed = true
        await viewModel.reload()
        gate.open()
        await more.value
        #expect(viewModel.posts.map(\.id) == ["fresh"])
    }

    // MARK: AI 検索

    @Test func ゲーム未選択なら全ゲームを検索して新着の代わりに結果を出す() async {
        listUseCase.handler = { _ in Fixture.page(["p"]) }
        searchUseCase.handler = { _ in [Fixture.post(id: "s1"), Fixture.post(id: "s2")] }
        let viewModel = make()
        await viewModel.reload()
        #expect(!viewModel.isSearchActive)
        await viewModel.search(query: "まったり", vcTool: .discord)
        #expect(viewModel.isSearchActive)
        #expect(viewModel.searchPhase == .results)
        #expect(viewModel.searchResults.map(\.id) == ["s1", "s2"])
        #expect(searchUseCase.requests == [SearchRequest(gameId: nil, query: "まったり", vcTool: .discord)])
    }

    @Test func 絞り込み中のゲームを検索し検索文を整えて送り短すぎる検索文は送らない() async {
        listUseCase.handler = { _ in Fixture.page([]) }
        searchUseCase.handler = { _ in [] }
        let viewModel = make()
        await viewModel.select(gameId: "apex-legends")
        await viewModel.search(query: "  まったり  ", vcTool: nil)
        await viewModel.search(query: " あ ", vcTool: nil)
        #expect(searchUseCase.requests == [SearchRequest(gameId: "apex-legends", query: "まったり", vcTool: nil)])
        #expect(viewModel.searchPhase == .empty)
    }

    @Test func 検索結果の表示中にゲームを変えると同じ検索文とVCで選んだゲームを検索し直す() async {
        listUseCase.handler = { _ in Fixture.page(["p"]) }
        searchUseCase.handler = { _ in [Fixture.post(id: "s")] }
        let viewModel = make()
        await viewModel.search(query: "まったり", vcTool: .discord)
        await viewModel.select(gameId: "apex-legends")
        await viewModel.select(gameId: nil)
        #expect(searchUseCase.requests == [
            SearchRequest(gameId: nil, query: "まったり", vcTool: .discord),
            SearchRequest(gameId: "apex-legends", query: "まったり", vcTool: .discord),
            SearchRequest(gameId: nil, query: "まったり", vcTool: .discord),
        ])
        // 解除したときに選んだゲームの新着が出るよう、新着も取り直しておく
        #expect(listUseCase.requestedGameIds == ["apex-legends", nil])
        #expect(viewModel.isSearchActive)
    }

    @Test func 検索していなければゲームを変えても検索しない() async {
        listUseCase.handler = { _ in Fixture.page(["p"]) }
        let viewModel = make()
        await viewModel.select(gameId: "apex-legends")
        #expect(searchUseCase.calls == 0)
        #expect(!viewModel.isSearchActive)
    }

    @Test func 検索を解除すると新着に戻り通信中だった検索の結果を出さない() async {
        let gate = Gate()
        searchUseCase.handler = { _ in
            await gate.pass()
            return [Fixture.post(id: "s")]
        }
        let viewModel = make()
        let searching = Task { await viewModel.search(query: "まったり", vcTool: nil) }
        await gate.waitForArrival()
        #expect(viewModel.searchPhase == .searching)
        viewModel.clearSearch()
        gate.open()
        await searching.value
        #expect(!viewModel.isSearchActive)
        #expect(viewModel.searchResults.isEmpty)
    }

    @Test func 引っ張って更新は検索結果の表示中なら同じ条件で検索し直し新着は取り直さない() async {
        listUseCase.handler = { _ in Fixture.page(["p"]) }
        searchUseCase.handler = { _ in [Fixture.post(id: "s")] }
        var now = Date(timeIntervalSince1970: 0)
        let viewModel = make(now: { now })
        await viewModel.search(query: "まったり", vcTool: .discord)
        now = now.addingTimeInterval(PostListViewModel.duplicateSearchInterval)
        await viewModel.refresh()
        let request = SearchRequest(gameId: nil, query: "まったり", vcTool: .discord)
        #expect(searchUseCase.requests == [request, request])
        #expect(listUseCase.requestedGameIds.isEmpty)

        viewModel.clearSearch()
        await viewModel.refresh()
        #expect(listUseCase.requestedGameIds == [nil])
        #expect(searchUseCase.calls == 2)
    }

    @Test func 後から届いた古い検索結果で上書きしない() async {
        let gate = Gate()
        searchUseCase.handler = { query in
            guard query == "最初の検索" else { return [Fixture.post(id: "new")] }
            await gate.pass()
            return [Fixture.post(id: "old")]
        }
        let viewModel = make()
        let first = Task { await viewModel.search(query: "最初の検索", vcTool: nil) }
        await gate.waitForArrival()
        await viewModel.search(query: "二回目の検索", vcTool: nil)
        gate.open()
        await first.value
        #expect(viewModel.searchResults.map(\.id) == ["new"])
        #expect(viewModel.searchPhase == .results)
    }

    @Test func 同じ条件の検索は通信中に送り直さず別条件なら送る() async {
        let gate = Gate()
        searchUseCase.handler = { query in
            if query == "のんびり遊びたい" { await gate.pass() }
            return []
        }
        let viewModel = make()
        let first = Task { await viewModel.search(query: "のんびり遊びたい", vcTool: nil) }
        await gate.waitForArrival()
        await viewModel.search(query: "のんびり遊びたい", vcTool: nil)
        #expect(searchUseCase.calls == 1)
        await viewModel.search(query: "ガチで周回したい", vcTool: nil)
        #expect(searchUseCase.calls == 2)
        gate.open()
        await first.value
    }

    @Test func 同じ条件の短時間の再検索は抑止し時間が経てば送る() async {
        searchUseCase.handler = { _ in [] }
        var now = Date(timeIntervalSince1970: 0)
        let viewModel = make(now: { now })
        await viewModel.search(query: "まったり", vcTool: nil)
        await viewModel.search(query: "まったり", vcTool: nil)
        #expect(searchUseCase.calls == 1)
        now = now.addingTimeInterval(PostListViewModel.duplicateSearchInterval)
        await viewModel.search(query: "まったり", vcTool: nil)
        #expect(searchUseCase.calls == 2)
    }

    @Test func 検索中に取り消されたら検索中のまま止まらず検索を解除した状態に戻る() async {
        let gate = Gate()
        searchUseCase.handler = { _ in
            await gate.pass()
            try Task.checkCancellation()
            return []
        }
        let viewModel = make()
        let searching = Task { await viewModel.search(query: "まったり", vcTool: nil) }
        await gate.waitForArrival()
        #expect(viewModel.searchPhase == .searching)
        searching.cancel()
        gate.open()
        await searching.value
        #expect(!viewModel.isSearchActive)

        searchUseCase.handler = { _ in [Fixture.post(id: "a")] }
        await viewModel.search(query: "まったり", vcTool: nil)
        #expect(viewModel.searchPhase == .results)
    }

    @Test func AI検索が使えなければ理由を出し引っ張って更新で検索し直せる() async {
        searchUseCase.handler = { _ in throw AppError.searchUnavailable }
        let viewModel = make()
        await viewModel.search(query: "まったり", vcTool: nil)
        #expect(viewModel.searchPhase == .unavailable)
        #expect(viewModel.searchErrorMessage == AppError.searchUnavailable.message)

        searchUseCase.handler = { _ in [Fixture.post(id: "a")] }
        await viewModel.refresh()
        #expect(viewModel.searchPhase == .results)
        #expect(viewModel.searchErrorMessage == nil)
    }

    @Test func 詳細で更新された募集を検索結果に反映する() async {
        searchUseCase.handler = { _ in [Fixture.post(id: "a"), Fixture.post(id: "b")] }
        let viewModel = make()
        await viewModel.search(query: "まったり", vcTool: nil)
        viewModel.applyToSearchResults(Fixture.post(id: "b", count: 1, joined: true))
        #expect(viewModel.searchResults.map(\.isJoinedByMe) == [false, true])
    }
}

@MainActor
struct GameCatalogStoreTests {
    let getGames = MockGetGamesUseCase()
    let games = [Game(id: "monster-hunter-wilds", displayName: "モンスターハンターワイルズ", aliases: ["モンハン"], isActive: true)]

    @Test func 取得に失敗したらエラーを出し次の表示で取り直す() async {
        getGames.executeHandler = { throw AppError.network }
        let store = GameCatalogStore(getGames: getGames)
        await store.loadIfNeeded()
        #expect(store.games == nil)
        #expect(store.error == .network)
        getGames.executeHandler = { [games] in games }
        await store.loadIfNeeded()
        #expect(store.games == games)
        #expect(store.error == nil)
    }

    @Test func 取得中に呼ばれたら新しく取得せず完了を待つ() async {
        let gate = Gate()
        var calls = 0
        getGames.executeHandler = { [games] in
            calls += 1
            await gate.pass()
            return games
        }
        let store = GameCatalogStore(getGames: getGames)
        let first = Task { await store.refresh() }
        await gate.waitForArrival()
        #expect(store.isLoading)
        let second = Task { await store.refresh() }
        gate.open()
        await second.value
        #expect(store.games == games)
        await first.value
        #expect(calls == 1)
        #expect(!store.isLoading)
    }

    @Test func 入力に合う候補が0件なら見つからないことを出す() async {
        getGames.executeHandler = { [games] in games }
        let viewModel = GamePickerViewModel(store: GameCatalogStore(getGames: getGames))
        await viewModel.load()
        viewModel.query = "存在しないゲーム"
        #expect(viewModel.showsNoMatch)
        viewModel.query = "モンハン"
        #expect(!viewModel.showsNoMatch)
    }
}
