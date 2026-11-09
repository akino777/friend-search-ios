import Alamofire
import Foundation

/// friend-search 業務 API（API Gateway HTTP API）。
/// 失敗は HTTPErrorAPIModel / URLError / DecodingError / CancellationError で返し、Alamofire の型を外へ出さない。
protocol FriendSearchAPI {
    func fetchGames() async throws -> GameCatalogAPIModel
    func fetchMe() async throws -> ProfileResponseAPIModel
    func bootstrap(_ body: DisplayNameRequestAPIModel) async throws -> ProfileResponseAPIModel
    func updateMe(_ body: DisplayNameRequestAPIModel) async throws -> ProfileResponseAPIModel
    /// gameId が nil なら全ゲームの新着
    func listPosts(gameId: String?, cursor: String?) async throws -> PostPageResponseAPIModel
    func createPost(_ body: CreatePostRequestAPIModel) async throws -> PostResponseAPIModel
    func getPost(id: String) async throws -> PostResponseAPIModel
    func joinPost(id: String) async throws -> PostResponseAPIModel
    func leavePost(id: String) async throws -> PostResponseAPIModel
    func closePost(id: String) async throws -> PostResponseAPIModel
    func searchPosts(_ body: PostSearchRequestAPIModel) async throws -> PostSearchResponseAPIModel
    func myPosts(cursor: String?) async throws -> PostPageResponseAPIModel
    func myParticipations(cursor: String?) async throws -> PostPageResponseAPIModel
}

/// 各リクエストに Amplify から取得した Access Token を `Authorization: Bearer` で付ける（トークンの更新は Amplify が行う）
final class DefaultFriendSearchAPI: FriendSearchAPI {
    /// 接続の再利用のため、インスタンス間で共有する
    private static let session: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 20
        return Session(configuration: configuration)
    }()

    private let baseURL: URL
    private let auth: any CognitoAuthAPI

    init(baseURL: URL = Endpoint.apiBaseURL, auth: any CognitoAuthAPI = DefaultCognitoAuthAPI()) {
        self.baseURL = baseURL
        self.auth = auth
    }

    func fetchGames() async throws -> GameCatalogAPIModel {
        try await send(.get, "games")
    }

    func fetchMe() async throws -> ProfileResponseAPIModel {
        try await send(.get, "me")
    }

    func bootstrap(_ body: DisplayNameRequestAPIModel) async throws -> ProfileResponseAPIModel {
        try await send(.post, "me/bootstrap", body: body)
    }

    func updateMe(_ body: DisplayNameRequestAPIModel) async throws -> ProfileResponseAPIModel {
        try await send(.patch, "me", body: body)
    }

    func listPosts(gameId: String?, cursor: String?) async throws -> PostPageResponseAPIModel {
        try await send(.get, "posts", query: ["gameId": gameId, "cursor": cursor])
    }

    func createPost(_ body: CreatePostRequestAPIModel) async throws -> PostResponseAPIModel {
        try await send(.post, "posts", body: body)
    }

    func getPost(id: String) async throws -> PostResponseAPIModel {
        try await send(.get, "posts/\(id)")
    }

    func joinPost(id: String) async throws -> PostResponseAPIModel {
        try await send(.post, "posts/\(id)/join")
    }

    func leavePost(id: String) async throws -> PostResponseAPIModel {
        try await send(.delete, "posts/\(id)/join")
    }

    func closePost(id: String) async throws -> PostResponseAPIModel {
        try await send(.post, "posts/\(id)/close")
    }

    func searchPosts(_ body: PostSearchRequestAPIModel) async throws -> PostSearchResponseAPIModel {
        try await send(.post, "posts/search", body: body)
    }

    func myPosts(cursor: String?) async throws -> PostPageResponseAPIModel {
        try await send(.get, "me/posts", query: ["cursor": cursor])
    }

    func myParticipations(cursor: String?) async throws -> PostPageResponseAPIModel {
        try await send(.get, "me/participations", query: ["cursor": cursor])
    }

    // MARK: 共通処理

    /// クエリ付き（または本文なし）のリクエスト。nil のクエリ値は送らない
    private func send<Response: Decodable & Sendable>(
        _ method: HTTPMethod, _ path: String, query: [String: String?]? = nil
    ) async throws -> Response {
        let headers = try await authorizationHeaders()
        return try await decode(Self.session.request(baseURL.appending(path: path), method: method, parameters: query, headers: headers))
    }

    /// JSON 本文付きのリクエスト
    private func send<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ method: HTTPMethod, _ path: String, body: Body
    ) async throws -> Response {
        let headers = try await authorizationHeaders()
        return try await decode(Self.session.request(
            baseURL.appending(path: path), method: method, parameters: body, encoder: JSONParameterEncoder.default, headers: headers
        ))
    }

    private func authorizationHeaders() async throws -> HTTPHeaders {
        [.authorization(bearerToken: try await auth.accessToken())]
    }

    /// エラー応答は本文を共通形式の APIModel として読み、HTTPErrorAPIModel にする
    private func decode<Response: Decodable & Sendable>(_ request: DataRequest) async throws -> Response {
        do {
            return try await request
                .validate { _, response, data in
                    guard !(200..<300).contains(response.statusCode) else { return .success(()) }
                    let body = data.flatMap { try? JSONDecoder().decode(ErrorResponseAPIModel.self, from: $0) }
                    return .failure(HTTPErrorAPIModel(statusCode: response.statusCode, body: body))
                }
                .serializingDecodable(Response.self)
                .value
        } catch let error as AFError {
            if error.isExplicitlyCancelledError { throw CancellationError() }
            throw error.underlyingError ?? error
        }
    }
}
