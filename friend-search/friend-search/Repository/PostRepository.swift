import Foundation

protocol PostRepository {
    func listPosts(gameId: String?, cursor: String?) async throws -> PostPage
    func search(gameId: String?, query: String, vcTool: VCTool?) async throws -> [Post]
    func post(id: String) async throws -> Post
    func create(_ newPost: NewPost, clientRequestId: UUID) async throws -> Post
    func join(postId: String) async throws -> Post
    func leave(postId: String) async throws -> Post
    func close(postId: String) async throws -> Post
    func myPosts(cursor: String?) async throws -> PostPage
    func myParticipations(cursor: String?) async throws -> PostPage
}

final class DefaultPostRepository: PostRepository {
    private let api: any FriendSearchAPI

    init(api: any FriendSearchAPI = DefaultFriendSearchAPI()) {
        self.api = api
    }

    func listPosts(gameId: String?, cursor: String?) async throws -> PostPage {
        try await withAppErrors { try PostPage(apiModel: try await api.listPosts(gameId: gameId, cursor: cursor)) }
    }

    func search(gameId: String?, query: String, vcTool: VCTool?) async throws -> [Post] {
        try await withAppErrors {
            let request = PostSearchRequestAPIModel(gameId: gameId, query: query, vcTool: vcTool?.rawValue)
            return try await api.searchPosts(request).items.map(Post.init(apiModel:))
        }
    }

    func post(id: String) async throws -> Post {
        try await withAppErrors { try Post(apiModel: try await api.getPost(id: id)) }
    }

    func create(_ newPost: NewPost, clientRequestId: UUID) async throws -> Post {
        try await withAppErrors { try Post(apiModel: try await api.createPost(newPost.toAPIModel(clientRequestId: clientRequestId))) }
    }

    func join(postId: String) async throws -> Post {
        try await withAppErrors { try Post(apiModel: try await api.joinPost(id: postId)) }
    }

    func leave(postId: String) async throws -> Post {
        try await withAppErrors { try Post(apiModel: try await api.leavePost(id: postId)) }
    }

    func close(postId: String) async throws -> Post {
        try await withAppErrors { try Post(apiModel: try await api.closePost(id: postId)) }
    }

    func myPosts(cursor: String?) async throws -> PostPage {
        try await withAppErrors { try PostPage(apiModel: try await api.myPosts(cursor: cursor)) }
    }

    func myParticipations(cursor: String?) async throws -> PostPage {
        try await withAppErrors { try PostPage(apiModel: try await api.myParticipations(cursor: cursor)) }
    }
}
