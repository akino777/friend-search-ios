import SwiftUI

/// P01 募集一覧（全ゲームの新着一覧・ゲームでの絞り込み・AI検索。検索結果は新着の欄に置き換えて出す）
struct PostListView: View {
    @Environment(GameCatalogStore.self) private var catalog
    @State private var viewModel: PostListViewModel
    @State private var showsGamePicker = false

    init(viewModel: PostListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                Button {
                    showsGamePicker = true
                } label: {
                    HStack {
                        Label(selectedGameName ?? "すべてのゲーム", systemImage: "gamecontroller")
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("list.gamePicker")
                if viewModel.selectedGameId != nil {
                    Button("絞り込みを解除", systemImage: "xmark.circle") {
                        Task { await viewModel.select(gameId: nil) }
                    }
                    .accessibilityIdentifier("list.clearGame")
                }
            } header: {
                Text("ゲームで絞り込む")
            }

            // ゲーム未選択なら全ゲームを検索する
            PostSearchEntrySection(viewModel: viewModel)

            if viewModel.isSearchActive {
                Section {
                    searchResults
                } header: {
                    Text("AI検索の結果")
                } footer: {
                    Text("文章の意味が近い募集を関連度順に表示します。投稿直後の募集は検索に表示されるまで少し時間がかかることがあります。")
                }
            } else {
                Section("新着の募集") {
                    content
                }
            }
        }
        .navigationTitle("募集を探す")
        .refreshable { await viewModel.refresh() }
        .navigationDestination(for: PostRoute.self) { route in
            PostRouteDestination(route: route)
        }
        .sheet(isPresented: $showsGamePicker) {
            GamePickerView(viewModel: GamePickerViewModel(store: catalog)) { game in
                Task { await viewModel.select(gameId: game.id) }
            }
        }
        .task { await viewModel.reload() }
    }

    private var selectedGameName: String? {
        viewModel.selectedGameId.map { catalog.displayName(for: $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            LoadingRow()
        case .empty:
            Text("まだ募集がありません。最初の募集を投稿してみましょう").foregroundStyle(.secondary)
        case .failed(let error):
            VStack(alignment: .leading, spacing: 8) {
                FormMessage(text: error.message)
                Button("再読み込み") { Task { await viewModel.reload() } }
            }
        case .loaded:
            ForEach(viewModel.posts) { post in
                NavigationLink(value: PostRoute.detail(post)) {
                    PostRowView(post: post)
                }
                .accessibilityIdentifier("post.row.\(post.id)")
                .task { await viewModel.loadMoreIfNeeded(current: post) }
            }
            if viewModel.isLoadingMore {
                LoadingRow()
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        switch viewModel.searchPhase {
        case .idle:
            EmptyView()
        case .searching:
            HStack { Spacer(); ProgressView("検索中…"); Spacer() }
        case .empty:
            Text("条件に合う募集が見つかりませんでした").foregroundStyle(.secondary)
        case .unavailable, .failed:
            if let message = viewModel.searchErrorMessage { FormMessage(text: message) }
        case .results:
            ForEach(viewModel.searchResults) { post in
                // 詳細での参加・取消を検索結果へ反映する（検索は費用がかかるので取り直さない）
                NavigationLink {
                    PostDetailView(viewModel: PostDetailViewModel(postId: post.id, initialPost: post, onUpdate: viewModel.applyToSearchResults))
                } label: {
                    PostRowView(post: post)
                }
            }
        }
    }
}

/// AI 検索の入力欄。入力状態をここに閉じ込め、1文字ごとに一覧全体を再評価しない
private struct PostSearchEntrySection: View {
    let viewModel: PostListViewModel
    @State private var query = ""
    @State private var vcFilter: VCTool?

    var body: some View {
        Section {
            TextField("例: 初心者に優しい人とまったり遊びたい", text: $query, axis: .vertical)
                .lineLimit(1...3)
                .accessibilityIdentifier("list.searchField")
            Picker("VC", selection: $vcFilter) {
                Text("指定なし").tag(nil as VCTool?)
                ForEach(VCTool.allCases) { tool in
                    Text(tool.displayName).tag(Optional(tool))
                }
            }
            Button {
                Task { await viewModel.search(query: query, vcTool: vcFilter) }
            } label: {
                Label("AIで募集を探す", systemImage: "sparkles")
            }
            .disabled(PostInputRule.normalizedQuery(query) == nil || viewModel.searchPhase == .searching)
            .accessibilityIdentifier("list.searchButton")
            if viewModel.isSearchActive {
                Button("検索を解除", systemImage: "xmark.circle") {
                    viewModel.clearSearch()
                }
                .accessibilityIdentifier("list.clearSearch")
            }
        } header: {
            Text("どんな人と遊びたい？")
        }
    }
}
