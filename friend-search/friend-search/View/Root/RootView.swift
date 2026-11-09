import SwiftUI

struct RootView: View {
    @State private var root = RootViewModel()

    var body: some View {
        Group {
            switch root.state {
            case .launching:
                ProgressView("読み込み中…")
            case .signedOut(let message):
                AuthFlowView(initialMessage: message) {
                    Task { await root.loadProfile() }
                }
            case .needsProfile(let avatar):
                ProfileSetupView(viewModel: ProfileSetupViewModel(), avatar: avatar) { profile in
                    root.didCreateProfile(profile)
                }
            case .profileLoadFailed(let error):
                ContentUnavailableView {
                    Label("プロフィールを取得できません", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error.message)
                } actions: {
                    Button("再試行") { Task { await root.loadProfile() } }
                        .buttonStyle(.borderedProminent)
                    Button("ログアウト", role: .destructive) { Task { await root.signOut() } }
                }
            case .ready(let profile):
                MainTabView(profile: profile)
            }
        }
        .environment(root)
        .task { await root.start() }
    }
}
