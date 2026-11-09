import Foundation

/// 画面の読み込み状態（idle / loading / loaded / empty / error を明示する）
enum ListPhase: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(AppError)
}
