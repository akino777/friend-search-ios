import SwiftUI

struct MainTabView: View {
    @Environment(RootViewModel.self) private var root
    @Environment(GameCatalogStore.self) private var catalog
    let profile: PublicProfile

    var body: some View {
        TabView {
            NavigationStack {
                PostListView(viewModel: PostListViewModel())
            }
            .tabItem { Label("探す", systemImage: "magnifyingglass") }

            NavigationStack {
                CreatePostView(viewModel: CreatePostViewModel())
            }
            .tabItem { Label("投稿", systemImage: "square.and.pencil") }

            NavigationStack {
                MyPageView(viewModel: MyPageViewModel(profile: profile, onProfileUpdated: root.didUpdateProfile))
            }
            .tabItem { Label("マイページ", systemImage: "person.crop.circle") }
        }
        .task { await catalog.loadIfNeeded() }
    }
}
