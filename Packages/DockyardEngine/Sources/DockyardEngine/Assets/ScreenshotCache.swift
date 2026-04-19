import CryptoKit
import Foundation
import os

public struct ScreenshotCache: Sendable {

    public let directory: URL
    private let urlSession: URLSession

    public init(directory: URL = ScreenshotCache.defaultDirectory, urlSession: URLSession = .shared) {
        self.directory = directory
        self.urlSession = urlSession
    }

    public static var defaultDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appending(path: "Dockyard/Screenshots")
    }

    public func localFile(for remoteURL: URL) async throws -> URL {
        let file = cacheFile(for: remoteURL)
        if FileManager.default.fileExists(atPath: file.path) {
            return file
        }
        try await download(remoteURL, to: file)
        return file
    }

    func cacheFile(for remoteURL: URL) -> URL {
        let key = Self.cacheKey(for: remoteURL)
        let ext = remoteURL.pathExtension.isEmpty ? "png" : remoteURL.pathExtension
        return directory.appending(path: "\(key).\(ext)")
    }

    private func download(_ url: URL, to destination: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let (tempURL, response) = try await urlSession.download(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                try? FileManager.default.removeItem(at: tempURL)
                throw EngineError.downloadFailed(underlying: "Screenshot HTTP \(http.statusCode)")
            }
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
        } catch let error as EngineError {
            throw error
        } catch {
            throw EngineError.downloadFailed(underlying: String(describing: error))
        }
    }

    static func cacheKey(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
