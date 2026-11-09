import SwiftUI

/// 探す・投稿・マイページのナビゲーション先
enum PostRoute: Hashable {
    case detail(Post)
}

/// ルートに応じて ViewModel を作って画面を返す
struct PostRouteDestination: View {
    let route: PostRoute

    var body: some View {
        switch route {
        case .detail(let post):
            PostDetailView(viewModel: PostDetailViewModel(postId: post.id, initialPost: post))
        }
    }
}
