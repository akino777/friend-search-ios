import SwiftUI

@main
struct FriendSearchApp: App {
    /// 画面をまたいで共有するゲームマスタ
    @State private var catalog = GameCatalogStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalog)
        }
    }
}
