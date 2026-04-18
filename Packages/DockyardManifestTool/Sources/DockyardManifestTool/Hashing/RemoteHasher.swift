import CryptoKit
import Foundation

struct RemoteHasher {

    let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func sha256(of url: URL) async throws -> String {
        let (bytes, response) = try await urlSession.bytes(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(
                domain: "RemoteHasher",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) while hashing \(url.absoluteString)"]
            )
        }

        var hasher = SHA256()
        var buffer = [UInt8]()
        buffer.reserveCapacity(1 << 16)
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= (1 << 16) {
                hasher.update(data: Data(buffer))
                buffer.removeAll(keepingCapacity: true)
            }
        }
        if !buffer.isEmpty {
            hasher.update(data: Data(buffer))
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
