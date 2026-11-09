import SwiftUI

/// P04 募集作成
struct CreatePostView: View {
    @Environment(GameCatalogStore.self) private var catalog
    @State private var viewModel: CreatePostViewModel
    @State private var showsGamePicker = false
    @State private var createdPost: Post?
    @FocusState private var focused: Field?

    enum Field { case body, capacity }

    init(viewModel: CreatePostViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section("ゲーム") {
                Button {
                    showsGamePicker = true
                } label: {
                    HStack {
                        Text(viewModel.selectedGame?.displayName ?? "ゲームを選択")
                            .foregroundStyle(viewModel.selectedGame == nil ? Color.accentColor : Color.primary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("create.gamePicker")
            }

            Section {
                ZStack(alignment: .topLeading) {
                    if viewModel.body.isEmpty {
                        Text("例: 今夜21時から、初心者同士でまったり遊べる人を募集！ミスしても気にしません。")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $viewModel.body)
                        .frame(minHeight: 140)
                        .focused($focused, equals: .body)
                        .accessibilityIdentifier("create.body")
                }
            } header: {
                Text("募集本文")
            } footer: {
                HStack {
                    Text("\(PostInputRule.bodyRange.lowerBound)〜\(PostInputRule.bodyRange.upperBound)文字")
                    Spacer()
                    Text("\(viewModel.bodyCount) / \(PostInputRule.bodyRange.upperBound)")
                        .foregroundStyle(viewModel.isBodyCountValid ? Color.secondary : Color.red)
                        .monospacedDigit()
                }
            }

            Section("ボイスチャット") {
                Picker("VCツール", selection: $viewModel.vcTool) {
                    ForEach(VCTool.allCases) { Text($0.displayName).tag($0) }
                }
                if viewModel.vcTool.usesInviteLink {
                    TextField("招待リンク（https://）", text: $viewModel.inviteUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("リンクは参加した人に表示されます")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    TextField("2", text: Binding(get: { viewModel.capacityText }, set: { viewModel.updateCapacityText($0) }))
                        .keyboardType(.numberPad)
                        .focused($focused, equals: .capacity)
                        .frame(maxWidth: 80)
                        .accessibilityIdentifier("create.capacity")
                    Text("人（あなたを除く）").foregroundStyle(.secondary)
                }
            } header: {
                Text("募集人数")
            } footer: {
                if let error = viewModel.capacityError { Text(error).foregroundStyle(.red) }
            }

            Section {
                if let message = viewModel.errorMessage { FormMessage(text: message) }
                SubmitButton(title: "投稿する", isLoading: viewModel.isSubmitting, isEnabled: viewModel.canSubmit) {
                    focused = nil
                    Task {
                        if let post = await viewModel.submit() { createdPost = post }
                    }
                }
                .accessibilityIdentifier("create.submit")
            }
        }
        .navigationTitle("募集を投稿")
        // キーボード上のツールバーは「投稿する」に重なりタップを奪うため使わず、スクロールで閉じる
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showsGamePicker) {
            GamePickerView(viewModel: GamePickerViewModel(store: catalog)) { game in
                viewModel.selectedGame = game
            }
        }
        .navigationDestination(item: $createdPost) { post in
            PostRouteDestination(route: .detail(post))
        }
    }
}
