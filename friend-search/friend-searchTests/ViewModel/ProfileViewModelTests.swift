import Foundation
import Testing

// プロフィールの ViewModel の入力検証。依存は UseCase のモックのみ。

@MainActor
struct ProfileNameTests {
    @Test func 表示名を整えて作成する() async {
        let bootstrap = MockBootstrapProfileUseCase()
        bootstrap.handler = { _ in Fixture.author }
        let viewModel = ProfileSetupViewModel(bootstrap: bootstrap)
        viewModel.displayName = " ハンター "
        #expect(await viewModel.submit() == Fixture.author)
        #expect(bootstrap.names == ["ハンター"])
    }

    @Test(arguments: [" あ ", String(repeating: "a", count: 25), "名前\u{0007}"])
    func 規則外の表示名は送らない(name: String) async {
        let bootstrap = MockBootstrapProfileUseCase()
        let viewModel = ProfileSetupViewModel(bootstrap: bootstrap)
        viewModel.displayName = name
        #expect(!viewModel.canSubmit)
        #expect(await viewModel.submit() == nil)
        #expect(viewModel.errorMessage == DisplayNameRule.invalidMessage)
        #expect(bootstrap.names.isEmpty)
    }

    @Test func 表示名の変更は規則を満たすときだけ保存してルートへ伝える() async {
        let update = MockUpdateProfileUseCase()
        let renamed = PublicProfile(publicUserId: "u", displayName: "新しい名前", avatarVersion: 1)
        update.handler = { _ in renamed }
        var notified: PublicProfile?
        let viewModel = MyPageViewModel(
            profile: Fixture.author, listMyPosts: MockListMyPostsUseCase(), updateProfile: update, onProfileUpdated: { notified = $0 }
        )
        viewModel.beginEditingName()
        #expect(viewModel.editingName == Fixture.author.displayName)
        viewModel.editingName = "x"
        #expect(!viewModel.canSaveName)
        #expect(await viewModel.saveName() == false)
        #expect(update.names.isEmpty)
        viewModel.editingName = " 新しい名前 "
        #expect(await viewModel.saveName())
        #expect(update.names == ["新しい名前"])
        #expect(viewModel.profile == renamed)
        #expect(notified == renamed)
    }
}
