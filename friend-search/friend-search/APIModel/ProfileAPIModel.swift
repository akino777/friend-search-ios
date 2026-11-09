import Foundation

nonisolated struct ProfileResponseAPIModel: Decodable, Sendable {
    let publicUserId: String
    let displayName: String
    let avatarVersion: Int
}

nonisolated struct DisplayNameRequestAPIModel: Encodable, Sendable {
    let displayName: String
}
