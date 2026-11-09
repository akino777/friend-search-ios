import Foundation

protocol RestoreSessionUseCase {
    /// 端末に保存されたセッションでログイン中か
    func execute() async throws -> Bool
}

struct DefaultRestoreSessionUseCase: RestoreSessionUseCase {
    private let repository: any AuthRepository

    init(repository: any AuthRepository = DefaultAuthRepository()) {
        self.repository = repository
    }

    func execute() async throws -> Bool {
        try await repository.isSignedIn()
    }
}
