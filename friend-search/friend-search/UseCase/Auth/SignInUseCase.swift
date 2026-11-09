import Foundation

protocol SignInUseCase {
    func execute(email: String, password: String) async throws -> SignInOutcome
}

struct DefaultSignInUseCase: SignInUseCase {
    private let repository: any AuthRepository

    init(repository: any AuthRepository = DefaultAuthRepository()) {
        self.repository = repository
    }

    func execute(email: String, password: String) async throws -> SignInOutcome {
        try await repository.signIn(email: email, password: password)
    }
}
