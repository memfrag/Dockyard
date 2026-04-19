import Foundation

public enum ReleaseChannel: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case beta = "Beta"
    case release = "Release"

    public var stringIfNotRelease: String? {
        switch self {
        case .release: nil
        default: rawValue
        }
    }
}
