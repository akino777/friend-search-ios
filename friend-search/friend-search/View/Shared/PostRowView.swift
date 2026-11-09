import SwiftUI

struct PostRowView: View {
    @Environment(GameCatalogStore.self) private var catalog
    let post: Post
    var showsGame = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IdenticonView(profile: post.author, size: 40)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(post.author.displayName).font(.subheadline.bold()).lineLimit(1)
                    Spacer()
                    StatusBadge(state: post.displayState)
                }
                if showsGame {
                    Text(catalog.displayName(for: post.gameId)).font(.caption).foregroundStyle(.secondary)
                }
                Text(post.body).font(.body).lineLimit(3)
                HStack(spacing: 12) {
                    Label(post.vcTool.displayName, systemImage: post.vcTool.systemImage)
                    Label("\(post.participantCount)/\(post.capacity)人", systemImage: "person.2")
                    if post.isJoinedByMe { Label("参加中", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                    Spacer()
                    Text(post.createdAt, format: .relative(presentation: .named))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct StatusBadge: View {
    let state: PostDisplayState

    var body: some View {
        Text(state.label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch state {
        case .recruiting: .green
        case .full: .orange
        case .closed: .gray
        }
    }
}
