import SwiftUI

/// P03 募集詳細（参加・取消・投稿者による終了）
struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameCatalogStore.self) private var catalog
    @State private var viewModel: PostDetailViewModel
    @State private var confirmsClose = false

    init(viewModel: PostDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if let post = viewModel.post {
                content(post)
            } else if let error = viewModel.loadError {
                ContentUnavailableView {
                    Label("読み込めませんでした", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error.message)
                } actions: {
                    Button("再試行") { Task { await viewModel.load() } }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("募集詳細")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
    }

    private func content(_ post: Post) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    IdenticonView(profile: post.author, size: 56)
                    VStack(alignment: .leading) {
                        Text(post.author.displayName).font(.headline)
                        Text(post.createdAt, format: .dateTime.month().day().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(state: post.displayState)
                }

                Label(catalog.displayName(for: post.gameId), systemImage: "gamecontroller")
                    .font(.subheadline.bold())

                Text(post.body)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 24) {
                    Label(post.vcTool.displayName, systemImage: post.vcTool.systemImage)
                    Label("\(post.participantCount) / \(post.capacity)人", systemImage: "person.2")
                        .accessibilityIdentifier("detail.count")
                }
                .font(.subheadline)
                Text("募集人数は投稿者を除いた人数です").font(.caption).foregroundStyle(.secondary)

                if let url = post.visibleInviteLink {
                    Link("\(post.vcTool.displayName) の招待リンクを開く", destination: url)
                        .buttonStyle(.borderedProminent)
                } else if post.showsInviteLinkHint {
                    Text("参加後に招待リンクを確認できます（リンクが登録されている場合）")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let message = viewModel.actionMessage {
                    FormMessage(text: message)
                }

                actions(post)
            }
            .padding()
        }
        .refreshable { await viewModel.load() }
        .alert("この募集を終了しますか？", isPresented: $confirmsClose) {
            Button("キャンセル", role: .cancel) {}
            Button("募集を終了する", role: .destructive) { Task { await viewModel.close() } }
        } message: {
            Text("終了すると新しい参加を受け付けません")
        }
    }

    @ViewBuilder
    private func actions(_ post: Post) -> some View {
        VStack(spacing: 12) {
            if post.isOwnedByMe {
                if post.canClose {
                    Button(role: .destructive) {
                        confirmsClose = true
                    } label: {
                        Text("募集を終了").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("detail.close")
                } else {
                    Text("この募集は終了しました").foregroundStyle(.secondary)
                }
            } else if post.isJoinedByMe {
                Label("参加中です", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Button(role: .destructive) {
                    Task { await viewModel.leave() }
                } label: {
                    actionLabel("参加を取り消す")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("detail.leave")
            } else {
                Button {
                    Task { await viewModel.join() }
                } label: {
                    actionLabel(post.joinButtonTitle)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!post.canJoin)
                .accessibilityIdentifier("detail.join")
            }
        }
        .disabled(viewModel.isProcessing)
    }

    private func actionLabel(_ title: String) -> some View {
        HStack {
            Spacer()
            if viewModel.isProcessing { ProgressView() } else { Text(title).bold() }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
