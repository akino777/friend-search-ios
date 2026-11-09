import Amplify
import AWSCognitoAuthPlugin
import Foundation
import Testing

// Model 層: APIModel / 外部のエラー → Model の変換

@MainActor
struct PostConversionTests {
    let author = ProfileResponseAPIModel(publicUserId: "id_001", displayName: "ユーザーA", avatarVersion: 1)

    func response(vcTool: String = "discord", status: String = "open", createdAt: String = "2026-11-01T10:00:00.123Z") -> PostResponseAPIModel {
        PostResponseAPIModel(
            id: "post_001", gameId: "monster-hunter-wilds", body: "乙っても気にしないで素材集めしよう！", vcTool: vcTool,
            capacity: 3, participantCount: 1, status: status, isJoinedByMe: false, isOwnedByMe: false,
            createdAt: createdAt, author: author
        )
    }

    @Test func JSONをデコードしてModelに変換する() throws {
        let json = """
        {"items":[{"id":"post_001","gameId":"monster-hunter-wilds","body":"本文","vcTool":"in_game","capacity":3,"participantCount":3,"status":"closed","isJoinedByMe":false,"isOwnedByMe":true,"createdAt":"2026-11-01T10:00:00Z","author":{"publicUserId":"id_001","displayName":"ユーザーA","avatarVersion":1},"inviteUrl":"https://discord.gg/abc"}],"nextCursor":"c1"}
        """
        let page = try PostPage(apiModel: JSONDecoder().decode(PostPageResponseAPIModel.self, from: Data(json.utf8)))
        let post = try #require(page.items.first)
        #expect(post.vcTool == .inGame)
        #expect(post.status == .closed)
        #expect(post.isOwnedByMe)
        #expect(post.author == PublicProfile(publicUserId: "id_001", displayName: "ユーザーA", avatarVersion: 1))
        #expect(post.inviteUrl == "https://discord.gg/abc")
        #expect(page.nextCursor == "c1")
    }

    @Test func 契約にない値は変換エラーにする() {
        #expect(throws: ModelConversionError.unknownVCTool("skype")) { try Post(apiModel: response(vcTool: "skype")) }
        #expect(throws: ModelConversionError.unknownPostStatus("draft")) { try Post(apiModel: response(status: "draft")) }
        #expect(throws: ModelConversionError.invalidDate("yesterday")) { try Post(apiModel: response(createdAt: "yesterday")) }
    }

    @Test func 日時は小数秒の有無どちらも読める() throws {
        #expect(abs(try Post(apiModel: response()).createdAt.timeIntervalSince1970 - 1_793_527_200.123) < 0.001)
        #expect(try Post(apiModel: response(createdAt: "2026-11-01T10:00:00Z")).createdAt == Date(timeIntervalSince1970: 1_793_527_200))
    }

    @Test func 募集作成の内容をAPIの値にする() throws {
        let requestId = UUID()
        let request = NewPost(gameId: "g", body: "b", vcTool: .playstationParty, capacity: 2).toAPIModel(clientRequestId: requestId)
        let object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(object["vcTool"] as? String == "playstation_party")
        #expect(object["clientRequestId"] as? String == requestId.uuidString.lowercased())
        #expect(Set(VCTool.allCases.map(\.rawValue)) == ["none", "discord", "line", "in_game", "playstation_party", "xbox_party", "other"])
    }
}

@MainActor
struct GameAndProfileConversionTests {
    @Test func ゲームを変換する() {
        let apiModel = GameAPIModel(id: "g", displayName: "ゲーム", aliases: ["略称"], active: false)
        #expect(Game(apiModel: apiModel) == Game(id: "g", displayName: "ゲーム", aliases: ["略称"], isActive: false))
    }

    @Test func プロフィール未作成の404だけを未作成として扱う() {
        let pending = ErrorResponseAPIModel.PendingAvatar(publicUserId: "u1", avatarVersion: 2)
        let notFound = HTTPErrorAPIModel(statusCode: 404, body: .init(error: .init(code: "PROFILE_NOT_FOUND", message: "m", pendingAvatar: pending)))
        #expect(ProfileLookup(notFoundError: notFound) == .notCreated(avatar: AvatarIdentity(publicUserId: "u1", avatarVersion: 2)))
        #expect(ProfileLookup(notFoundError: HTTPErrorAPIModel(statusCode: 404, body: nil)) == nil)
        #expect(ProfileLookup(notFoundError: URLError(.timedOut)) == nil)
    }
}

@MainActor
struct AuthResultConversionTests {
    @Test func サインインの次の手順() {
        #expect(SignInOutcome(apiModel: AuthSignInResult(nextStep: .done)) == .signedIn)
        #expect(SignInOutcome(apiModel: AuthSignInResult(nextStep: .confirmSignInWithTOTPCode)) == .unsupportedStep)
    }
}

@MainActor
struct AppErrorConversionTests {
    func http(_ status: Int, code: String? = nil) -> HTTPErrorAPIModel {
        HTTPErrorAPIModel(statusCode: status, body: code.map { ErrorResponseAPIModel(error: .init(code: $0, message: "m", pendingAvatar: nil)) })
    }

    @Test func エラーコードで分類する() {
        #expect(AppError(error: http(409, code: "POST_FULL")) == .postFull)
        #expect(AppError(error: http(409, code: "POST_CLOSED")) == .postClosed)
        #expect(AppError(error: http(503, code: "SEARCH_UNAVAILABLE")) == .searchUnavailable)
        #expect(AppError(error: http(403, code: "FORBIDDEN")) == .forbidden(serverMessage: "m"))
        #expect(AppError(error: http(500, code: "INTERNAL")) == .server(status: 500, serverMessage: "m"))
    }

    @Test func 共通形式の本文がなければHTTPステータスで分類する() {
        #expect(AppError(error: http(401)) == .unauthorized)
        #expect(AppError(error: http(429)) == .rateLimited)
        #expect(AppError(error: http(503)) == .temporarilyUnavailable)
        #expect(AppError(error: http(502)) == .server(status: 502, serverMessage: nil))
    }

    @Test func 通信障害と契約違反() {
        #expect(AppError(error: URLError(.notConnectedToInternet)) == .network)
        #expect(AppError(error: ModelConversionError.unknownVCTool("x")) == .invalidResponse)
        #expect(AppError(error: CocoaError(.fileNoSuchFile)) == .unexpected)
    }

    @Test func 認証エラーを分類する() {
        #expect(AppError(error: AuthError.sessionExpired("", "", nil)) == .unauthorized)
        #expect(AppError(error: AuthError.notAuthorized("", "", nil)) == .auth(.invalidCredentials))
        #expect(AppError(error: AuthError.service("", "", URLError(.timedOut))) == .network)
    }
}
