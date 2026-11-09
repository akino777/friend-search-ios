import SwiftUI

/// 未ログイン時の画面。ログインは用意済みのアカウントで行う
struct AuthFlowView: View {
    let initialMessage: String?
    let onSignedIn: () -> Void

    var body: some View {
        NavigationStack {
            SignInView(viewModel: SignInViewModel(), message: initialMessage, onSignedIn: onSignedIn)
        }
    }
}
