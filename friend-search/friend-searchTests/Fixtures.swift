import Foundation

/// 各層のテストで共有する Model のテストデータ（Model はどの層からも参照される）
enum Fixture {
    static let author = PublicProfile(publicUserId: "u", displayName: "ユーザー", avatarVersion: 1)

    static func post(id: String, count: Int = 0, joined: Bool = false) -> Post {
        Post(
            id: id, gameId: "g", author: author,
            body: "テスト用の募集本文です。よろしくお願いします。", vcTool: .discord, capacity: 3, participantCount: count,
            status: .open, isJoinedByMe: joined, isOwnedByMe: false, createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    static func page(_ ids: [String], next: String? = nil) -> PostPage {
        PostPage(items: ids.map { post(id: $0) }, nextCursor: next)
    }
}

/// モックで未設定の処理が呼ばれたことを示す
struct Unimplemented: Error {}

/// テストで非同期処理の順番を決めるための関門。モックの中で `pass()` を呼ぶと、`open()` されるまでそこで止まる。
/// 時間待ち（sleep）に頼らずに「通信中」「後から応答が届く」状況を作る。
@MainActor
final class Gate {
    private var isOpen = false
    private var blocked: [CheckedContinuation<Void, Never>] = []
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var arrivals = 0

    /// モックの中で呼ぶ。open されるまで待つ
    func pass() async {
        arrivals += 1
        arrivalWaiters.forEach { $0.resume() }
        arrivalWaiters.removeAll()
        guard !isOpen else { return }
        await withCheckedContinuation { blocked.append($0) }
    }

    /// pass に count 回到達する（＝処理が通信中で止まる）まで待つ
    func waitForArrival(count: Int = 1) async {
        while arrivals < count {
            await withCheckedContinuation { arrivalWaiters.append($0) }
        }
    }

    func open() {
        isOpen = true
        blocked.forEach { $0.resume() }
        blocked.removeAll()
    }
}
