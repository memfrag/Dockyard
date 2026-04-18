import ArgumentParser
import DockyardEngine
import Foundation

@main
struct DockyardManifestTool: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "dockyard-manifest-tool",
        abstract: "Build a Dockyard catalog manifest from a config file by resolving each app's latest GitHub release.",
        subcommands: [Build.self, SetToken.self, ClearToken.self],
        defaultSubcommand: Build.self
    )
}

// MARK: - build

extension DockyardManifestTool {

    struct Build: AsyncParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "build",
            abstract: "Resolve releases and write manifest.json."
        )

        @Option(name: .shortAndLong, help: "Path to the authoring config JSON.")
        var config: String

        @Option(name: .shortAndLong, help: "Path to write the manifest JSON.")
        var output: String

        @Flag(name: .long, help: "Download each DMG and compute its SHA-256. Skipped by default.")
        var hash: Bool = false

        mutating func run() async throws {
            let configURL = URL(fileURLWithPath: config)
            let outputURL = URL(fileURLWithPath: output)

            let authoringConfig: AuthoringConfig
            do {
                authoringConfig = try AuthoringConfig.load(from: configURL)
            } catch {
                FileHandle.standardError.write(Data("Failed to read config: \(error)\n".utf8))
                throw ExitCode(1)
            }

            let token: String?
            do {
                token = try KeychainTokenStore().load()
            } catch {
                FileHandle.standardError.write(Data("Keychain error: \(error)\n".utf8))
                throw ExitCode(5)
            }

            let api = GitHubAPIClient(token: token)
            let hasher: RemoteHasher? = hash ? RemoteHasher() : nil
            let builder = ManifestBuilder(api: api, hasher: hasher)

            let manifest: CatalogManifest
            do {
                manifest = try await builder.build(config: authoringConfig)
            } catch let error as GitHubAPIError {
                FileHandle.standardError.write(Data("\(error)\n".utf8))
                throw ExitCode(2)
            } catch let error as AssetSelectorError {
                FileHandle.standardError.write(Data("\(error)\n".utf8))
                throw ExitCode(3)
            } catch {
                FileHandle.standardError.write(Data("Network or builder error: \(error)\n".utf8))
                throw ExitCode(4)
            }

            let wrote: Bool
            do {
                wrote = try ManifestWriter.write(manifest, to: outputURL)
            } catch {
                FileHandle.standardError.write(Data("Write failed: \(error)\n".utf8))
                throw ExitCode(1)
            }
            if wrote {
                print("Wrote \(output) (\(manifest.apps.count) apps)")
            } else {
                print("No changes; \(output) is up to date (\(manifest.apps.count) apps)")
            }
        }
    }
}

// MARK: - set-token

extension DockyardManifestTool {

    struct SetToken: AsyncParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "set-token",
            abstract: "Store a GitHub token in the Keychain (reads from stdin; not echoed)."
        )

        @Option(name: .long, help: "Token value. If omitted, the tool prompts on stdin.")
        var token: String?

        mutating func run() async throws {
            let value: String
            if let token {
                value = token
            } else {
                value = Self.readTokenFromStdin()
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                FileHandle.standardError.write(Data("Empty token; nothing stored\n".utf8))
                throw ExitCode(1)
            }

            do {
                try KeychainTokenStore().save(trimmed)
                print("Stored GitHub token in Keychain (service: \(KeychainTokenStore.service))")
            } catch {
                FileHandle.standardError.write(Data("Keychain error: \(error)\n".utf8))
                throw ExitCode(5)
            }
        }

        private static func readTokenFromStdin() -> String {
            FileHandle.standardError.write(Data("Enter GitHub token (input hidden): ".utf8))
            if isatty(fileno(stdin)) != 0,
               let input = String(validatingCString: getpass("")) {
                return input
            }
            return readLine() ?? ""
        }
    }
}

// MARK: - clear-token

extension DockyardManifestTool {

    struct ClearToken: AsyncParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "clear-token",
            abstract: "Remove the stored GitHub token from the Keychain."
        )

        mutating func run() async throws {
            do {
                try KeychainTokenStore().clear()
                print("Cleared GitHub token from Keychain")
            } catch {
                FileHandle.standardError.write(Data("Keychain error: \(error)\n".utf8))
                throw ExitCode(5)
            }
        }
    }
}
