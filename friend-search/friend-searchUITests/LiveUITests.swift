import XCTest

/// モックを使わず、実アプリから dev 環境へ接続して、投稿・新着一覧・AI検索・参加・取消・終了をサーバーまで通す。
/// 画面の細かい状態はユニットテストで確かめるので、ここでは扱わない。
/// scripts/ios-live-uitest.sh が環境変数 FS_LIVE_ACCOUNTS で専用アカウントを渡す（未指定ならスキップ）。
final class LiveUITests: XCTestCase {
    private struct Accounts: Decodable {
        let password: String
        let emails: [String]
    }

    private static let game = "apex-legends"
    private static let timeout: TimeInterval = 30
    private var app: XCUIApplication!
    private var accounts: Accounts!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let json = ProcessInfo.processInfo.environment["FS_LIVE_ACCOUNTS"] else {
            throw XCTSkip("FS_LIVE_ACCOUNTS が未指定のためスキップ（scripts/ios-live-uitest.sh で実行）")
        }
        accounts = try JSONDecoder().decode(Accounts.self, from: Data(json.utf8))
        XCTAssertGreaterThanOrEqual(accounts.emails.count, 2)
    }

    @MainActor
    func test投稿から検索と参加と取消と終了まで通る() throws {
        // 合言葉の数字は実行ごとに変え、一覧・検索結果から自分の募集を見つける目印にする
        let token = String(format: "%08d", Int.random(in: 0..<100_000_000))
        let body = "週末の夜にまったり遊べる人を募集しています。初心者同士、気楽にいきましょう。合言葉は「\(token)」で。"
        let (owner, joiner) = (accounts.emails[0], accounts.emails[1])
        launchSignedOut()

        // 投稿者: 投稿する
        signIn(owner, displayName: "ハルト")
        tapTab("投稿")
        tap(app.buttons["create.gamePicker"].firstMatch)
        tap(app.buttons["game.\(Self.game)"].firstMatch)
        let bodyField = app.textViews["create.body"].firstMatch
        tap(bodyField)
        bodyField.typeText(body)
        let capacity = app.textFields["create.capacity"].firstMatch
        tap(capacity)
        capacity.typeText(XCUIKeyboardKey.delete.rawValue)
        capacity.typeText("3")
        tap(app.buttons["create.submit"].firstMatch)
        XCTAssertTrue(appeared(app.buttons["detail.close"].firstMatch), "投稿後に詳細へ遷移しない")
        signOut()

        // 参加者: 新着一覧に出ることと AI 検索で見つかることを確かめ、参加して取り消す
        signIn(joiner, displayName: "りん")
        tapTab("探す")
        waitInList(token: token)
        searchInList(query: body, token: token)
        tap(row(containing: token))
        tap(app.buttons["detail.join"].firstMatch)
        assertCount(1)
        tap(app.buttons["detail.leave"].firstMatch)
        assertCount(0)
        signOut()

        // 投稿者: マイページから募集を終了する
        signIn(owner, displayName: "ハルト")
        tapTab("マイページ")
        tap(row(containing: token))
        tap(app.buttons["detail.close"].firstMatch)
        tap(app.alerts.buttons["募集を終了する"].firstMatch)
        XCTAssertTrue(appeared(app.staticTexts["この募集は終了しました"]), "募集を終了できない")
    }

    // MARK: - 認証

    /// 前回のセッションが残っていても、ログイン画面から始める
    @MainActor
    private func launchSignedOut() {
        app = XCUIApplication()
        app.launch()
        let signInField = app.textFields["signIn.email"]
        let tabBar = app.tabBars.firstMatch
        let setup = app.textFields["profile.displayName"]
        let deadline = Date().addingTimeInterval(Self.timeout)
        while Date() < deadline, !signInField.exists, !tabBar.exists, !setup.exists {
            _ = signInField.waitForExistence(timeout: 1)
        }
        if signInField.exists { return }
        if setup.exists { completeProfile(displayName: "ハルト") }
        signOut()
    }

    /// 初回はプロフィール作成も通す。作成済みのアカウントならそのままタブ画面へ進む
    @MainActor
    private func signIn(_ email: String, displayName: String) {
        let emailField = app.textFields["signIn.email"]
        tap(emailField)
        emailField.typeText(email)
        let passwordField = app.secureTextFields["signIn.password"]
        tap(passwordField)
        passwordField.typeText(accounts.password)
        tap(app.buttons["signIn.submit"].firstMatch)

        let setup = app.textFields["profile.displayName"]
        let tabBar = app.tabBars.firstMatch
        let deadline = Date().addingTimeInterval(Self.timeout)
        while Date() < deadline, !setup.exists, !tabBar.exists {
            _ = tabBar.waitForExistence(timeout: 1)
        }
        // ログイン後（実測で送信の2〜7秒後）に iOS が出す保存の確認。保存済みなどで出ない場合はそのまま進む
        if savePasswordPromptButton.waitForExistence(timeout: 15) { closeSavePasswordPrompt() }
        if setup.exists { completeProfile(displayName: displayName) }
        XCTAssertTrue(appeared(tabBar), "\(email) でログインできない")
    }

    @MainActor
    private func completeProfile(displayName: String) {
        let field = app.textFields["profile.displayName"]
        tap(field)
        field.typeText(displayName)
        tap(app.buttons["profile.submit"].firstMatch)
        XCTAssertTrue(appeared(app.tabBars.firstMatch), "プロフィールを作成できない")
    }

    @MainActor
    private func signOut() {
        tapTab("マイページ")
        let signOutButton = app.buttons["mypage.signOut"].firstMatch
        for _ in 0..<5 where !signOutButton.isHittable {
            app.swipeUp()
        }
        tap(signOutButton)
        tap(app.alerts.buttons["ログアウト"].firstMatch)
        XCTAssertTrue(appeared(app.textFields["signIn.email"]), "ログアウトできない")
    }

    /// iOS がログイン後に出す「パスワードを保存しますか？」の「今はしない」。アプリの要素として取得できる
    @MainActor
    private var savePasswordPromptButton: XCUIElement { app.buttons["今はしない"].firstMatch }

    /// 表示直後のタップでは閉じないことがある（実測）ため、閉じるまで押し直す
    @MainActor
    private func closeSavePasswordPrompt() {
        for _ in 0..<10 where savePasswordPromptButton.exists {
            savePasswordPromptButton.tap()
            _ = savePasswordPromptButton.waitForNonExistence(timeout: 3)
        }
        XCTAssertFalse(savePasswordPromptButton.exists, "パスワード保存の確認を閉じられない")
    }

    // MARK: - 募集

    /// 反映遅延（GSI）を許容し、引っ張って更新しながら一覧に出るのを待つ
    @MainActor
    private func waitInList(token: String) {
        let target = row(containing: token)
        for _ in 0..<10 where !target.waitForExistence(timeout: 3) {
            app.collectionViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(target.exists, "新着一覧に募集が表示されない")
    }

    /// AI 検索し、投稿した募集が結果に出るまで待つ。Embedding の生成を待つため、出るまで引っ張って更新で検索し直す。
    /// 同じ条件は直前の完了から5秒以内だと送られないので10秒待ってから更新する（検索回数の上限に配慮して10回まで）
    @MainActor
    private func searchInList(query: String, token: String) {
        let field = app.textFields["list.searchField"].firstMatch
        tap(field)
        field.typeText(query)
        tap(app.buttons["list.searchButton"].firstMatch)
        XCTAssertTrue(appeared(app.buttons["list.clearSearch"].firstMatch), "検索結果に切り替わらない")
        let target = row(containing: token)
        for _ in 0..<10 where !target.waitForExistence(timeout: 10) {
            app.collectionViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(target.exists, "AI検索の結果に投稿した募集が出ない")
    }

    @MainActor
    private func assertCount(_ expected: Int) {
        let label = NSPredicate(format: "label BEGINSWITH %@", "\(expected) / ")
        let count = app.descendants(matching: .any).matching(identifier: "detail.count").matching(label).firstMatch
        XCTAssertTrue(appeared(count), "参加人数が \(expected) にならない")
    }

    // MARK: - 共通

    @MainActor
    private func appeared(_ element: XCUIElement) -> Bool {
        element.waitForExistence(timeout: Self.timeout)
    }

    @MainActor
    private func row(containing token: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", token)).firstMatch
    }

    @MainActor
    private func tapTab(_ name: String) {
        tap(app.tabBars.buttons[name])
    }

    @MainActor
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: Self.timeout), "見つからない: \(element)", file: file, line: line)
        // 保存の確認が遅れて出ていたら、操作を遮らないよう先に閉じる
        if savePasswordPromptButton.exists { closeSavePasswordPrompt() }
        element.tap()
    }
}
