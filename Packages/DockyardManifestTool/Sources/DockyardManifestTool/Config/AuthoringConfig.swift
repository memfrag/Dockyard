import Foundation

struct AuthoringConfig: Codable, Sendable {

    let apps: [AuthoringEntry]

    /// Browser-based entries. Kept beside `apps` rather than inside it because
    /// they have no GitHub repo, no release and no `.dockyard/` folder — none of
    /// the resolution `apps` goes through applies to them.
    let webApps: [AuthoringWebApp]

    init(apps: [AuthoringEntry], webApps: [AuthoringWebApp]) {
        self.apps = apps
        self.webApps = webApps
    }

    private enum CodingKeys: String, CodingKey {
        case apps, webApps
    }

    /// `webApps` is optional on the way in so every existing config keeps loading.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apps = try container.decode([AuthoringEntry].self, forKey: .apps)
        webApps = try container.decodeIfPresent([AuthoringWebApp].self, forKey: .webApps) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(apps, forKey: .apps)
        // Omitted when empty so `add` doesn't introduce a key into configs that
        // have no web apps.
        if !webApps.isEmpty {
            try container.encode(webApps, forKey: .webApps)
        }
    }

    static func load(from url: URL) throws -> AuthoringConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AuthoringConfig.self, from: data)
    }
}
