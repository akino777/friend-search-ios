import Foundation

protocol BootstrapProfileUseCase {
    func execute(displayName: String) async throws -> PublicProfile
}

struct DefaultBootstrapProfileUseCase: BootstrapProfileUseCase {
    private let repository: any ProfileRepository

    init(repository: any ProfileRepository = DefaultProfileRepository()) {
        self.repository = repository
    }

    func execute(displayName: String) async throws -> PublicProfile {
        try await repository.bootstrap(displayName: displayName)
    }
}
