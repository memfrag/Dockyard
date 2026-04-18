import Foundation

public enum InstallPhase: Sendable, Equatable {
    case idle
    case queued
    case downloadingDMG(DownloadProgress)
    case verifyingHash
    case mounting
    case copying
    case verifyingSignature
    case finalizing
    case installed
    case cancelled
    case failed(EngineError)

    /// `true` while the engine is actively working on this app (queued, downloading, or in-pipeline).
    public var isInFlight: Bool {
        switch self {
        case .queued, .downloadingDMG, .verifyingHash, .mounting, .copying, .verifyingSignature, .finalizing:
            return true
        case .idle, .installed, .cancelled, .failed:
            return false
        }
    }

    /// Download fraction `0.0...1.0` when in `.downloadingDMG`, else `nil`.
    public var downloadFraction: Double? {
        if case .downloadingDMG(let progress) = self { return progress.fraction }
        return nil
    }
}
