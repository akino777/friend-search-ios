# friend-search for iOS

![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![iOS 17+](https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)

ゲームを一緒に遊ぶ相手を探すアプリの iOS 版です。
ゲームを選んで募集を投稿し、新着一覧・ゲームでの絞り込み・自然文の AI 検索で相手を探せます。
Android 版も、同じ機能と同じ層構成で作っています。

> [!NOTE]
> デモ用のアプリです。新規登録・パスワード再設定の機能はなく、あらかじめ用意したアカウントでログインします。

## 主な機能

| 画面 | できること |
| --- | --- |
| ログイン | 用意済みのアカウント（メールアドレスとパスワード）でログイン |
| 表示名の設定 | 初回だけ表示名（2〜24文字）を決める |
| 探す | 全ゲームの新着一覧、ゲームでの絞り込み、自然文の AI 検索（意味が近い募集を関連度順に表示） |
| 投稿 | ゲーム・本文・VC ツール（Discord / LINE / ゲーム内 VC など）・募集人数（1〜10人）・招待リンクを入力して募集 |
| 募集の詳細 | 参加・参加の取り消し・投稿者による募集の終了。招待リンクは投稿者と参加者にだけ表示 |
| マイページ | 表示名と Identicon、自分の募集、参加中の募集、ログアウト |

## 技術スタック

| 分類 | 使っているもの |
| --- | --- |
| 言語・UI | Swift 6（言語モード 6）、SwiftUI、Observation（`@Observable`） |
| 認証 | Amplify Swift（AWSCognitoAuthPlugin）。Amazon Cognito に SRP でログイン |
| API 通信 | Alamofire |
| テスト | Swift Testing（ユニットテスト）、XCTest（UI テスト） |
| パッケージ管理 | Swift Package Manager |

## アーキテクチャ

```mermaid
flowchart LR
    View --> ViewModel --> UseCase --> Repository --> API["API（Data）"]
```

```
friend-search/friend-search/
├── View/         SwiftUI の画面。@main（View/Root/FriendSearchApp）も View の一部。各画面が自分の ViewModel を作る
├── ViewModel/    @Observable・@MainActor の画面状態・入力検証・表示用の値（文言・ラベル・候補検索・Identicon）
├── UseCase/      ケースごとの Repository の呼び方（protocol と実装 Default*）
├── Repository/   API の結果を Model・AppError に変換する（protocol と実装 Default*）
├── API/          Data: FriendSearchAPI（Alamofire）、CognitoAuthAPI（Amplify）、Endpoint（接続先）
├── APIModel/     API とやり取りする外部の形（JSON の Codable 型。認証は Amplify の結果型）
└── Model/        各層で共有するデータの型と、APIModel・外部のエラーからの変換（init(apiModel:) など）
```

- **依存の向き**: 各層は1つ下の層を protocol として初期化子で受け取ります。既定値は本番の実装（`Default*`）で、テストではモックを渡します。DI コンテナは使いません。
- **入力検証とエラー文言**: ViewModel が行います（`ViewModel/Shared/InputRules.swift`・`ErrorMessage.swift`）。最終的な判定はサーバーです。
- **画面をまたぐ状態**: `GameCatalogStore`・`RootViewModel` を SwiftUI の Environment で渡します。
- **データの取り直し**: 一覧・詳細は表示のたびに取り直します。AI 検索は費用がかかるため、引っ張って更新したときとゲームを変えたときだけ検索し直し、詳細で変えた内容だけを結果に反映します。端末にキャッシュは持ちません。
- **並行処理**: Swift 6 言語モードでデータ競合をコンパイル時に検出します。古い応答は世代番号で捨て、取り消しは SwiftUI の `.task` に任せます。
- **認証**: 既存の Cognito User Pool に `AmplifyOutputsData` で接続し、最初の呼び出し時に一度だけ設定します。トークンの保管と更新は Amplify に任せ、API には Access Token を `Authorization: Bearer` で付けます。
- **Identicon**: `avatarVersion:publicUserId` の SHA-256 から 5×5 の左右対称パターンを作ります（`ViewModel/Shared/IdenticonPattern.swift`）。Android 版と同じ仕様です。

## ビルドと実行

Xcode 27.2 でビルドを確認しています。

### 1. 接続先を置く

接続先の値はリポジトリに含めていません。共有された値で `friend-search/friend-search/API/DevEndpoint.swift` を作ってください（Git の管理外です）。

```swift
import Foundation

nonisolated enum DevEndpoint {
    static let apiBaseURL = URL(string: "https://api.example.com/v1")!
    static let userPoolId = "ap-northeast-1_XXXXXXXXX"
    static let userPoolClientId = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

client secret や IAM の資格情報は使いません。

### 2. スキームを選んで実行する

`friend-search/friend-search.xcodeproj` を開き、スキームを選んでシミュレータで実行します。

| スキーム | 接続先 | 用途 |
| --- | --- | --- |
| `friend-search-Dev` | dev（`DevEndpoint.swift` の値） | 動作確認・開発 |
| `friend-search-Prod` | prod（未構築のため接続先は空） | ビルドの確認 |

2つのスキームの違いは接続先だけです。`API/Endpoint.swift` がコンパイル条件 `DEV` で切り替えます。
`DevEndpoint.swift` はどちらのスキームでもビルドに必要です（Prod だけを使う場合は、上の雛形のままでかまいません）。

実機で動かすときは、ターゲットの Signing & Capabilities で自分の Team と Bundle ID を設定してください（リポジトリでは Team を空にしています）。

## テスト

```sh
./scripts/ios-verify.sh                  # パッケージ解決 → Dev / Prod のビルド → Dev でユニットテスト・UI テスト
./scripts/ios-verify.sh --skip-ui-tests
```

ユニットテスト（`friend-searchTests`）は層ごとに分け、各層は1つ下の層のモックだけを使います。
非同期の順番は `Gate`（`Fixtures.swift`）で決め、sleep による時間待ちには頼りません。
アプリは起動せず、テストする層のソースをテストターゲットにも含めて直接コンパイルします（`@testable import` は使いません）。
これらのフォルダにファイルを追加したら、Target Membership で `friend-searchTests` にもチェックを入れてください。

| フォルダ | 対象 | 差し込むモック |
| --- | --- | --- |
| `Model/` | APIModel・外部のエラー → Model の変換 | なし |
| `ViewModel/` | 画面状態・入力検証・表示用の値・多重実行の抑止・古い結果の破棄 | `UseCaseMocks.swift` |
| `Repository/` | API の結果 → Model・AppError | `DataMocks.swift` |

### 実環境 UI テスト（開発者向け）

実アプリから dev 環境へ接続し、ログイン・投稿・新着一覧・AI 検索・参加・取り消し・終了までをサーバー経由で通します。

```sh
aws sso login --profile friend-dev && ./scripts/ios-live-uitest.sh
```

バックエンドのリポジトリ（非公開）と dev 環境の AWS の権限が必要です。
テスト用アカウントはバックエンド側のスクリプトが用意し、認証情報は環境変数で渡します。環境変数がなければこのテストはスキップされます。
