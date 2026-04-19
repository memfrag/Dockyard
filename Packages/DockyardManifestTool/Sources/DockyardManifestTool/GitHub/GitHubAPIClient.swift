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
        let (data, http) = try await send(request: authedRequest(for: url))

        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(GitHubRelease.self, from: data)
            } catch {
                throw GitHubAPIError.transport(underlying: "Decode failed: \(error)")
            }
        case 401:
            throw GitHubAPIError.unauthorized
        case 404:
            throw GitHubAPIError.notFound(owner: owner, repo: repo)
        case 403:
            throw rateLimitErrorOrFallback(http: http, data: data)
        default:
            throw GitHubAPIError.unexpectedStatus(http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
    }

    /// Lists the contents of a directory within a repo. Returns `[]` when the directory
    /// is absent (HTTP 404) — callers treat missing `.dockyard/` folders as "no assets".
    func listDirectory(owner: String, repo: String, path: String) async throws -> [GitHubContentsEntry] {
        guard let url = contentsURL(owner: owner, repo: repo, path: path) else { return [] }
        let (data, http) = try await send(request: authedRequest(for: url))

        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode([GitHubContentsEntry].self, from: data)
            } catch {
                throw GitHubAPIError.transport(underlying: "Decode failed: \(error)")
            }
        case 404:
            return []
        case 401:
            throw GitHubAPIError.unauthorized
        case 403:
            throw rateLimitErrorOrFallback(http: http, data: data)
        default:
            throw GitHubAPIError.unexpectedStatus(http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
    }

    /// Fetches metadata for a single file within a repo. Returns `nil` when the file
    /// is absent (HTTP 404) — callers treat missing `.dockyard/about.md` as "no about page".
    func getFile(owner: String, repo: String, path: String) async throws -> GitHubContentsEntry? {
        guard let url = contentsURL(owner: owner, repo: repo, path: path) else { return nil }
        let (data, http) = try await send(request: authedRequest(for: url))

        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(GitHubContentsEntry.self, from: data)
            } catch {
                throw GitHubAPIError.transport(underlying: "Decode failed: \(error)")
            }
        case 404:
            return nil
        case 401:
            throw GitHubAPIError.unauthorized
        case 403:
            throw rateLimitErrorOrFallback(http: http, data: data)
        default:
            throw GitHubAPIError.unexpectedStatus(http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
    }

    // MARK: - Private helpers

    private func contentsURL(owner: String, repo: String, path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/repos/\(owner)/\(repo)/contents/\(path)"
        return components.url
    }

    private func authedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
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
        return (data, http)
    }

    private func rateLimitErrorOrFallback(http: HTTPURLResponse, data: Data) -> GitHubAPIError {
        let remaining = http.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap { Int($0) } ?? -1
        if remaining == 0 {
            let resetEpoch = http.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap { Double($0) }
            let resetsAt = resetEpoch.map { Date(timeIntervalSince1970: $0) }
            return .rateLimited(resetsAt: resetsAt)
        }
        return .unexpectedStatus(403, body: String(decoding: data, as: UTF8.self))
    }
}
