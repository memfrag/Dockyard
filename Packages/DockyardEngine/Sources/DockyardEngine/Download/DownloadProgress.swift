import Foundation

public struct DownloadProgress: Sendable, Equatable {

    public let bytesWritten: Int64
    public let bytesExpected: Int64

    public init(bytesWritten: Int64, bytesExpected: Int64) {
        self.bytesWritten = bytesWritten
        self.bytesExpected = bytesExpected
    }

    /// Fraction in `0.0...1.0`, or `nil` when the total size is unknown.
    public var fraction: Double? {
        guard bytesExpected > 0 else { return nil }
        return Double(bytesWritten) / Double(bytesExpected)
    }
}
