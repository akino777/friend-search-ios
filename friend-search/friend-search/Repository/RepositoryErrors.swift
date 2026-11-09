import Foundation

/// API / SDK のエラーを AppError に置き換える（変換規則は Model の `AppError.init(error:)` に定義）
func withAppErrors<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch {
        // 取り消し（画面離脱など）はエラーとして表示しない
        if error is CancellationError || Task.isCancelled { throw CancellationError() }
        throw AppError(error: error)
    }
}
