import SwiftUI

/// フォームのエラー・案内表示
struct FormMessage: View {
    enum Kind { case error, info }
    let text: String
    var kind: Kind = .error

    var body: some View {
        Label(text, systemImage: kind == .error ? "exclamationmark.circle" : "info.circle")
            .font(.footnote)
            .foregroundStyle(kind == .error ? Color.red : Color.secondary)
            .accessibilityIdentifier(kind == .error ? "form.error" : "form.info")
    }
}

/// リストの中央に出す読み込み中表示
struct LoadingRow: View {
    var body: some View {
        ProgressView().frame(maxWidth: .infinity)
    }
}

/// 処理中はスピナーを出して二重タップを防ぐボタン
struct SubmitButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isLoading { ProgressView() } else { Text(title).bold() }
                Spacer()
            }
        }
        .disabled(!isEnabled || isLoading)
    }
}
