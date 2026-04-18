import Foundation
import os

struct Downloader: Sendable {

    let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// Downloads `url` to a temp file and returns the local file URL.
    /// `progress` is called on an unspecified queue for each received chunk.
    /// Honours Swift Concurrency cancellation.
    func download(
        from url: URL,
        progress: @Sendable @escaping (DownloadProgress) -> Void
    ) async throws -> URL {
        let delegate = DownloadDelegate(progress: progress)
        let request = URLRequest(url: url)
        do {
            let (tempURL, response) = try await urlSession.download(for: request, delegate: delegate)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                try? FileManager.default.removeItem(at: tempURL)
                throw EngineError.downloadFailed(underlying: "HTTP \(http.statusCode)")
            }
            return tempURL
        } catch is CancellationError {
            throw EngineError.cancelled
        } catch let error as EngineError {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                throw EngineError.cancelled
            }
            throw EngineError.downloadFailed(underlying: String(describing: error))
        }
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    private let progress: @Sendable (DownloadProgress) -> Void

    init(progress: @Sendable @escaping (DownloadProgress) -> Void) {
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progress(DownloadProgress(
            bytesWritten: totalBytesWritten,
            bytesExpected: totalBytesExpectedToWrite
        ))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // URLSession's async variant is responsible for moving/returning the file.
    }
}
