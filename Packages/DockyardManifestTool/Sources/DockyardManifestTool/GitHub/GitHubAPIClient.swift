import Foundation

enum GitHubAPIError: Error, CustomStringConvertible {
    case unauthorized
    case notFound(owner: String, repo: String)
    case rateLimited(resetsAt: Date?)
    case unexpectedStatus(Int, body: String)
    case transport(underlying: String)

    var description: String {
        switch self {
        case .unauthorized:
            return "GitHub API returned 401 Unauthorized — check the Keychain token"
        case .notFound(let owner, let repo):
            return "GitHub API returned 404 for \(owner)/\(repo) — no published releases?"
        case .rateLimited(let resetsAt):
            if let resetsAt {
                return "GitHub rate limit hit; resets at \(resetsAt)"
            }
            return "GitHub rate limit hit"
        case .unexpectedStatus(let code, let body):
            return "GitHub API returned HTTP \(code): \(body.prefix(200))"
        case .transport(let underlying):
            return "Transport error talking to GitHub: \(underlying)"
        }
    }
}

struct GitHubAPIClient {

    let urlSession: URLSession
    let token: String?
    let userAgent: String

    init(urlSession: URLSession = .shared, token: String?, userAgent: String = "dockyard-manifest-tool/1.0") {
        self.urlSession = urlSession
        self.token = token
        self.userAgent = userAgent
    }

    func latestRelease(owner: String, repo: String) async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw GitHubAPIError.transport(underlying: String(describing: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw GitHubAPIError.transport(underlying: "Non-HTTP response")
        }
        switch http.statusCode {
        case 200:
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(GitHubRelease.self, from: data)
            } catch {
                throw GitHubAPIError.transport(underlying: "Decode failed: \(error)")
            }
        case 401:
            throw GitHubAPIError.unauthorized
        case 404:
            throw GitHubAPIError.notFound(owner: owner, repo: repo)
        case 403:
            let remaining = http.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap { Int($0) } ?? -1
            if remaining == 0 {
                let resetEpoch = http.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap { Double($0) }
                let resetsAt = resetEpoch.map { Date(timeIntervalSince1970: $0) }
                throw GitHubAPIError.rateLimited(resetsAt: resetsAt)
            }
            throw GitHubAPIError.unexpectedStatus(403, body: String(decoding: data, as: UTF8.self))
        default:
            throw GitHubAPIError.unexpectedStatus(http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
    }
}
