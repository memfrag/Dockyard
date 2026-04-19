import Foundation

public struct GitHubRepo: Codable, Equatable, Hashable, Sendable {

    public let owner: String
    public let repo: String

    public init(owner: String, repo: String) {
        self.owner = owner
        self.repo = repo
    }

    public var url: URL {
        URL(string: "https://github.com/\(owner)/\(repo)")!
    }
}

extension Optional<GitHubRepo>: Hashable {
    
}
