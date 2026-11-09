import Foundation

/// 接続先。Dev スキーム（コンパイル条件 DEV）は dev 環境、それ以外は prod 環境へ接続する。
/// dev の値は公開リポジトリに載せないため、Git 管理外の `DevEndpoint.swift` に置く（テストする人には別途伝える）。
/// `DevEndpoint.swift` は friend-search-infra の `scripts/write-ios-config.sh` が terraform output から書き出す。
/// client secret や IAM 資格情報は置かない。
nonisolated enum Endpoint {
    static let awsRegion = "ap-northeast-1"

    #if DEV
    static let apiBaseURL = DevEndpoint.apiBaseURL
    static let userPoolId = DevEndpoint.userPoolId
    static let userPoolClientId = DevEndpoint.userPoolClientId
    #else
    // prod 環境は未構築。構築後に値を入れる
    static let apiBaseURL = URL(string: "https://prod.invalid/v1")!
    static let userPoolId = ""
    static let userPoolClientId = ""
    #endif
}
