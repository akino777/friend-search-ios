import Foundation

protocol SignOutUseCase {
    func execute() async throws
}

struct DefaultSignOutUseCase: SignOutUseCase {
    private let repository: any AuthRepository

    init(repository: any AuthRepository = DefaultAuthRepository()) {
        self.repository = repository
    }

    func execute() async throws {
        try await repository.signOut()
    }
}
