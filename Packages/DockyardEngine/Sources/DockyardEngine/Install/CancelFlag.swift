import Foundation

/// A tiny thread-safe boolean used to signal cancellation across actor boundaries.
/// Reference-type so callers can capture it in closures and see the latest value.
final class CancelFlag: @unchecked Sendable {

    private let lock = NSLock()
    private var flag: Bool = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return flag
    }

    func cancel() {
        lock.lock()
        flag = true
        lock.unlock()
    }
}
