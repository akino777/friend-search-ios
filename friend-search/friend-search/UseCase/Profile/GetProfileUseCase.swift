import Foundation

protocol GetProfileUseCase {
    func execute() async throws -> ProfileLookup
}

struct DefaultGetProfileUseCase: GetProfileUseCase {
    private let repository: any ProfileRepository

    init(repository: any ProfileRepository = DefaultProfileRepository()) {
        self.repository = repository
    }

    func execute() async throws -> ProfileLookup {
        try await repository.myProfile()
    }
}
