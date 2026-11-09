import Foundation

/// APIModel から Model への変換時の契約違反
nonisolated enum ModelConversionError: Error, Equatable {
    case unknownVCTool(String)
    case unknownPostStatus(String)
    case invalidDate(String)
}
