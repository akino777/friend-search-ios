import SwiftUI

/// A04 表示名設定（初回プロフィール作成）
struct ProfileSetupView: View {
    @State private var viewModel: ProfileSetupViewModel
    let avatar: AvatarIdentity?
    let onCreated: (PublicProfile) -> Void

    init(viewModel: ProfileSetupViewModel, avatar: AvatarIdentity?, onCreated: @escaping (PublicProfile) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.avatar = avatar
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        if let avatar {
                            IdenticonView(publicUserId: avatar.publicUserId, avatarVersion: avatar.avatarVersion, size: 80)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.quaternary)
                                .frame(width: 80, height: 80)
                                .overlay(Image(systemName: "square.grid.3x3.fill").font(.largeTitle).foregroundStyle(.secondary))
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("あなたのアイコンです。自動で作られ、画像のアップロードはありません")
                        .frame(maxWidth: .infinity)
                }
                Section {
                    TextField("表示名", text: $viewModel.displayName)
                        .textContentType(.nickname)
                        .accessibilityIdentifier("profile.displayName")
                } header: {
                    Text("表示名")
                } footer: {
                    Text("\(DisplayNameRule.range.lowerBound)〜\(DisplayNameRule.range.upperBound)文字。他のユーザーに表示されます")
                }
                Section {
                    if let message = viewModel.errorMessage { FormMessage(text: message) }
                    SubmitButton(title: "はじめる", isLoading: viewModel.isSubmitting, isEnabled: viewModel.canSubmit) {
                        Task {
                            if let profile = await viewModel.submit() { onCreated(profile) }
                        }
                    }
                    .accessibilityIdentifier("profile.submit")
                }
            }
            .navigationTitle("プロフィール設定")
        }
    }
}
