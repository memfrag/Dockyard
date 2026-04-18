import Foundation

public enum EngineError: Error, Sendable, Equatable {

    case manifestUnreachable(underlying: String)
    case manifestDecodeFailed(underlying: String)
    case unsupportedSchemaVersion(found: Int, expected: Int)
    case downloadFailed(underlying: String)
    case hashMismatch(expected: String, actual: String)
    case mountFailed(stderr: String)
    case noAppInDMG
    case destinationOccupied(path: String)
    case bundleIdentifierMismatch(expected: String, found: String)
    case verificationFailed(tool: VerificationTool, stderr: String)
    case appIsRunning(bundleID: String)
    case cancelled
    case notInstalled(id: String)
    case fileSystemError(underlying: String)

    public enum VerificationTool: String, Sendable {
        case codesign
        case spctl
    }
}

extension EngineError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .manifestUnreachable(let underlying):
            return "Manifest unreachable: \(underlying)"
        case .manifestDecodeFailed(let underlying):
            return "Manifest decode failed: \(underlying)"
        case .unsupportedSchemaVersion(let found, let expected):
            return "Unsupported manifest schema version \(found); expected \(expected)"
        case .downloadFailed(let underlying):
            return "Download failed: \(underlying)"
        case .hashMismatch(let expected, let actual):
            return "Hash mismatch (expected \(expected), got \(actual))"
        case .mountFailed(let stderr):
            return "Failed to mount DMG: \(stderr)"
        case .noAppInDMG:
            return "No .app bundle found at the root of the mounted DMG"
        case .destinationOccupied(let path):
            return "Destination occupied by an untracked bundle: \(path)"
        case .bundleIdentifierMismatch(let expected, let found):
            return "Bundle identifier mismatch (expected \(expected), found \(found))"
        case .verificationFailed(let tool, let stderr):
            return "\(tool.rawValue) verification failed: \(stderr)"
        case .appIsRunning(let bundleID):
            return "App is currently running: \(bundleID)"
        case .cancelled:
            return "Install cancelled"
        case .notInstalled(let id):
            return "App is not installed: \(id)"
        case .fileSystemError(let underlying):
            return "File system error: \(underlying)"
        }
    }
}
