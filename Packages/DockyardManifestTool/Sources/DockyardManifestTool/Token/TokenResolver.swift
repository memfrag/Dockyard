import Foundation

/// Resolves the GitHub token used for API requests.
///
/// Precedence: `DOCKYARD_GITHUB_TOKEN` env var, then `GITHUB_TOKEN` env var,
/// then the Keychain. When an env token is present the Keychain is never
/// touched, so CI runs don't trigger Keychain prompts or errors.
enum TokenResolver {

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> String? {
        for key in ["DOCKYARD_GITHUB_TOKEN", "GITHUB_TOKEN"] {
            if let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return try KeychainTokenStore().load()
    }
}
