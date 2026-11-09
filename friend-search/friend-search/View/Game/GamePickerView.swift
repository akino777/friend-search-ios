import SwiftUI

/// G01 ゲーム選択（端末内のマスタを表示名・別名で候補検索。AIで判定しない）
struct GamePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GamePickerViewModel
    let onSelect: (Game) -> Void

    init(viewModel: GamePickerViewModel, onSelect: @escaping (Game) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.store.games == nil {
                    if viewModel.store.isLoading {
                        LoadingRow()
                    } else if let error = viewModel.store.error {
                        FormMessage(text: error.message)
                        Button("再読み込み") { Task { await viewModel.store.refresh() } }
                    }
                }
                ForEach(viewModel.candidates) { game in
                    Button {
                        onSelect(game)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.displayName).foregroundStyle(.primary)
                            if !game.aliases.isEmpty {
                                Text(game.aliases.joined(separator: " / ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .accessibilityIdentifier("game.\(game.id)")
                }
                if viewModel.showsNoMatch {
                    Text("「\(viewModel.query)」は見つかりませんでした")
                        .foregroundStyle(.secondary)
                }
            }
            .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "ゲーム名・略称で検索")
            .autocorrectionDisabled()
            .navigationTitle("ゲームを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .refreshable { await viewModel.store.refresh() }
            .task { await viewModel.load() }
        }
    }
}
