import Foundation

protocol ProfileRepository {
    func myProfile() async throws -> ProfileLookup
    func bootstrap(displayName: String) async throws -> PublicProfile
    func updateDisplayName(_ displayName: String) async throws -> PublicProfile
}

final class DefaultProfileRepository: ProfileRepository {
    private let api: any FriendSearchAPI

    init(api: any FriendSearchAPI = DefaultFriendSearchAPI()) {
        self.api = api
    }

    func myProfile() async throws -> ProfileLookup {
        try await withAppErrors {
            do {
                return .found(PublicProfile(apiModel: try await api.fetchMe()))
            } catch {
                guard let notCreated = ProfileLookup(notFoundError: error) else { throw error }
                return notCreated
            }
        }
    }

    func bootstrap(displayName: String) async throws -> PublicProfile {
        try await withAppErrors { PublicProfile(apiModel: try await api.bootstrap(DisplayNameRequestAPIModel(displayName: displayName))) }
    }

    func updateDisplayName(_ displayName: String) async throws -> PublicProfile {
        try await withAppErrors { PublicProfile(apiModel: try await api.updateMe(DisplayNameRequestAPIModel(displayName: displayName))) }
    }
}
