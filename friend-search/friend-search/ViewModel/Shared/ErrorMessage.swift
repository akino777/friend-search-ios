import Foundation

// 通信・認証エラーを画面に表示する文言にする

nonisolated extension AppError {
    var message: String {
        switch self {
        case .validation(let serverMessage): serverMessage ?? "入力内容を確認してください"
        case .unknownGame: "このゲームは選択できません。ゲーム一覧を更新してください"
        case .unauthorized: "ログインの有効期限が切れました。再度ログインしてください"
        case .forbidden(let serverMessage): serverMessage ?? "この操作は許可されていません"
        case .profileRequired: "先にプロフィールを作成してください"
        case .profileNotFound: "プロフィールが未作成です"
        case .notFound: "募集が見つかりませんでした"
        case .postFull: "募集人数に達しました"
        case .postClosed: "この募集は終了しています"
        case .idempotencyConflict: "送信内容が変わったため投稿できませんでした。もう一度投稿してください"
        case .concurrentUpdate: "他の操作と競合しました。最新の状態を確認してください"
        case .rateLimited: "操作が多すぎます。少し時間を空けてからお試しください"
        case .searchUnavailable: "現在AI検索を利用できません"
        case .temporarilyUnavailable: "一時的に処理できませんでした。再度お試しください"
        case .server(let status, let serverMessage): serverMessage ?? "サーバーエラーが発生しました（\(status)）"
        case .network: "通信できませんでした。ネットワーク接続を確認してください"
        case .invalidResponse: "サーバーの応答を読み取れませんでした"
        case .unexpected: "予期しないエラーが発生しました"
        case .auth(let failure): failure.message
        }
    }
}

nonisolated extension AuthFailure {
    var message: String {
        switch self {
        case .invalidCredentials: "メールアドレスまたはパスワードが正しくありません"
        case .limitExceeded: "試行回数が上限に達しました。しばらく時間を空けてください"
        case .userNotFound: "アカウントが見つかりません"
        case .unexpected(let detail): "認証でエラーが発生しました（\(detail)）"
        }
    }
}
