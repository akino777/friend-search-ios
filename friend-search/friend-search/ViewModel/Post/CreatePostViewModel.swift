import Foundation
import Observation

/// 募集作成
@MainActor
@Observable
final class CreatePostViewModel {
    var selectedGame: Game?
    var body = ""
    var vcTool: VCTool = .none
    var inviteUrl = ""
    private(set) var capacityText = String(PostInputRule.defaultCapacity)
    private(set) var isSubmitting = false
    var errorMessage: String?

    private let createPost: any CreatePostUseCase
    /// 結果が分からなかった送信。同じ内容の再送には同じ clientRequestId を使い、サーバーでの重複作成を防ぐ
    private var pending: (draft: NewPost, requestId: UUID)?

    init(createPost: any CreatePostUseCase = DefaultCreatePostUseCase()) {
        self.createPost = createPost
    }

    var bodyCount: Int { PostInputRule.normalizedBody(body).count }
    var isBodyCountValid: Bool { PostInputRule.bodyRange.contains(bodyCount) }
    var capacity: Int? { PostInputRule.capacity(from: capacityText) }
    var capacityError: String? { capacity == nil ? PostInputRule.capacityMessage : nil }
    var canSubmit: Bool { selectedGame != nil && isBodyCountValid && capacity != nil && !isSubmitting }

    /// 数字キーボードでも貼り付けなどで数字以外が入り得るため、半角数字だけ2桁まで残す
    func updateCapacityText(_ text: String) {
        capacityText = String(text.filter { $0.isASCII && $0.isNumber }.prefix(2))
    }

    func submit() async -> Post? {
        guard !isSubmitting else { return nil }
        errorMessage = nil
        guard let draft = validatedDraft() else { return nil }
        let requestId = requestId(for: draft)
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let post = try await createPost.execute(draft, clientRequestId: requestId)
            pending = nil
            reset()
            return post
        } catch {
            errorMessage = AppError(error: error).message
            return nil
        }
    }

    /// 入力を検証して募集内容にする。不正なら理由を errorMessage に出して nil
    private func validatedDraft() -> NewPost? {
        guard let game = selectedGame else {
            errorMessage = PostInputRule.gameMissingMessage
            return nil
        }
        guard isBodyCountValid else {
            errorMessage = PostInputRule.bodyMessage
            return nil
        }
        guard let capacity else {
            errorMessage = PostInputRule.capacityMessage
            return nil
        }
        var link: String?
        if vcTool.usesInviteLink {
            guard let valid = PostInputRule.inviteLink(inviteUrl, for: vcTool) else {
                errorMessage = PostInputRule.inviteLinkMessage
                return nil
            }
            link = valid
        }
        return NewPost(gameId: game.id, body: PostInputRule.normalizedBody(body), vcTool: vcTool, capacity: capacity, inviteUrl: link)
    }

    private func requestId(for draft: NewPost) -> UUID {
        if let pending, pending.draft == draft { return pending.requestId }
        let id = UUID()
        pending = (draft, id)
        return id
    }

    private func reset() {
        body = ""
        vcTool = .none
        inviteUrl = ""
        capacityText = String(PostInputRule.defaultCapacity)
    }
}
