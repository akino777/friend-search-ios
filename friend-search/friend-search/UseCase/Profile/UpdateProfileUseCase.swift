import Foundation

protocol UpdateProfileUseCase {
    func execute(displayName: String) async throws -> PublicProfile
}

struct DefaultUpdateProfileUseCase: UpdateProfileUseCase {
    private let repository: any ProfileRepository

    init(repository: any ProfileRepository = DefaultProfileRepository()) {
        self.repository = repository
    }

    func execute(displayName: String) async throws -> PublicProfile {
        try await repository.updateDisplayName(displayName)
    }
}
