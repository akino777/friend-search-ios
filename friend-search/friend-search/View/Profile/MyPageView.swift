import SwiftUI

/// M01 マイページ（表示名・Identicon、自分の募集、参加中一覧、ログアウト）
struct MyPageView: View {
    @Environment(RootViewModel.self) private var root
    @State private var viewModel: MyPageViewModel
    @State private var editsName = false
    @State private var confirmsSignOut = false

    init(viewModel: MyPageViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    IdenticonView(profile: viewModel.profile, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.profile.displayName).font(.title3.bold())
                            .accessibilityIdentifier("mypage.displayName")
                        Button("表示名を変更") {
                            viewModel.beginEditingName()
                            editsName = true
                        }
                        .font(.footnote)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("表示", selection: $viewModel.segment) {
                    ForEach(MyPageViewModel.Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.segment) { viewModel.segmentChanged() }

                switch viewModel.phase {
                case .idle, .loading:
                    LoadingRow()
                case .empty:
                    Text(viewModel.emptyMessage)
                        .foregroundStyle(.secondary)
                case .failed(let error):
                    FormMessage(text: error.message)
                    Button("再読み込み") { Task { await viewModel.reload() } }
                case .loaded:
                    ForEach(viewModel.visiblePosts) { post in
                        NavigationLink(value: PostRoute.detail(post)) {
                            PostRowView(post: post, showsGame: true)
                        }
                        .task { await viewModel.loadMoreIfNeeded(current: post) }
                    }
                    if viewModel.isLoadingMore {
                        LoadingRow()
                    } else if let error = viewModel.loadMoreError {
                        FormMessage(text: error.message)
                        Button("続きを再読み込み") { Task { await viewModel.loadMore() } }
                    }
                }
            }

            Section {
                Button("ログアウト", role: .destructive) { confirmsSignOut = true }
                    .accessibilityIdentifier("mypage.signOut")
            }
        }
        .navigationTitle("マイページ")
        .refreshable { await viewModel.reload() }
        .task { await viewModel.reload() }
        .navigationDestination(for: PostRoute.self) { route in
            PostRouteDestination(route: route)
        }
        .alert("ログアウトしますか？", isPresented: $confirmsSignOut) {
            Button("キャンセル", role: .cancel) {}
            Button("ログアウト", role: .destructive) {
                Task { await root.signOut() }
            }
        }
        .sheet(isPresented: $editsName) {
            NavigationStack {
                Form {
                    TextField("表示名", text: $viewModel.editingName)
                    if let error = viewModel.nameError { FormMessage(text: error) }
                }
                .navigationTitle("表示名を変更")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { editsName = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            Task { if await viewModel.saveName() { editsName = false } }
                        }
                        .disabled(!viewModel.canSaveName)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
