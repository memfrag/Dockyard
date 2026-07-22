import ArgumentParser
import Foundation

extension DockyardManifestTool {

    struct Add: AsyncParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Register a new app repo in the authoring config, scaffolding .dockyard/dockyard.json when the repo lacks one."
        )

        @Argument(help: "The GitHub repo as owner/repo.")
        var repository: String

        @Option(name: .shortAndLong, help: "Path to the authoring config JSON.")
        var config: String

        @Option(name: .long, help: "Write the scaffolded dockyard.json to this path instead of printing it.")
        var scaffoldOut: String?

        @Option(name: .long, help: "Regex used to select the release asset. Defaults to the first *.dmg.")
        var assetPattern: String?

        mutating func run() async throws {
            let parts = repository.split(separator: "/")
            guard parts.count == 2 else {
                BuildRunner.fail("Expected owner/repo, got: \(repository)")
                throw ExitCode(1)
            }
            let owner = String(parts[0])
            let repo = String(parts[1])

            let configURL = URL(fileURLWithPath: config)
            let authoringConfig: AuthoringConfig
            do {
                authoringConfig = try AuthoringConfig.load(from: configURL)
            } catch {
                BuildRunner.fail("Failed to read config: \(error)")
                throw ExitCode(1)
            }
            guard !authoringConfig.apps.contains(where: { $0.github.owner == owner && $0.github.repo == repo }) else {
                BuildRunner.fail("\(repository) is already in \(config)")
                throw ExitCode(1)
            }

            let token: String?
            do {
                token = try TokenResolver.resolve()
            } catch {
                BuildRunner.fail("Keychain error: \(error)")
                throw ExitCode(5)
            }
            let api = GitHubAPIClient(token: token)

            let hasMetadata: Bool
            do {
                let release = try await api.latestRelease(owner: owner, repo: repo)
                let asset = try AssetSelector.select(from: release.assets, pattern: assetPattern)
                hasMetadata = try await checkRepoMetadata(api: api, owner: owner, repo: repo)
                if !hasMetadata {
                    try await scaffold(asset: asset, repository: repository)
                }
            } catch let error as GitHubAPIError {
                BuildRunner.fail("\(error)")
                throw ExitCode(2)
            } catch let error as AssetSelectorError {
                BuildRunner.fail("\(error)")
                throw ExitCode(3)
            } catch let error as RepoMetadataError {
                BuildRunner.fail("\(error)")
                throw ExitCode(6)
            } catch let error as ExitCode {
                throw error
            } catch {
                BuildRunner.fail("Network or inspection error: \(error)")
                throw ExitCode(4)
            }

            let entry = AuthoringEntry(
                github: AuthoringEntry.GitHub(owner: owner, repo: repo),
                assetPattern: assetPattern
            )
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let updated = AuthoringConfig(apps: authoringConfig.apps + [entry])
                try encoder.encode(updated).write(to: configURL, options: .atomic)
            } catch {
                BuildRunner.fail("Failed to update config: \(error)")
                throw ExitCode(1)
            }
            print("Added \(repository) to \(config)")

            if !hasMetadata {
                print("""

                Next steps:
                  1. Commit .dockyard/dockyard.json (and .dockyard/AppIcon.png) to \(repository)
                  2. Fill in the TODO category/summary fields
                  3. Run build (or publish) to add the app to the catalog
                """)
            }
        }

        /// Returns true when the repo already has a valid `.dockyard/dockyard.json`.
        private func checkRepoMetadata(api: GitHubAPIClient, owner: String, repo: String) async throws -> Bool {
            guard let file = try await api.getFile(owner: owner, repo: repo, path: ".dockyard/dockyard.json"),
                  let downloadURL = file.downloadURL else {
                return false
            }
            let (data, _) = try await URLSession.shared.data(from: downloadURL)
            _ = try RepoMetadata.decode(data, owner: owner, repo: repo)
            return true
        }

        /// Downloads the DMG once to discover the bundle identifier and name,
        /// then emits a ready-to-commit dockyard.json scaffold.
        private func scaffold(asset: GitHubAsset, repository: String) async throws {
            print("No .dockyard/dockyard.json in \(repository); downloading \(asset.name) once to inspect it...")
            let (tempURL, _) = try await URLSession.shared.download(from: asset.browserDownloadURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let info: DmgInspector.AppInfo
            do {
                info = try DmgInspector().inspect(dmgAt: tempURL)
            } catch let error as DmgInspectorError {
                BuildRunner.fail("\(error)")
                throw ExitCode(4)
            }

            let scaffold = Self.scaffoldJSON(bundleID: info.bundleID, name: info.name, assetName: asset.name)
            if let scaffoldOut {
                try Data(scaffold.utf8).write(to: URL(fileURLWithPath: scaffoldOut), options: .atomic)
                print("Wrote scaffold to \(scaffoldOut)")
            } else {
                print("Scaffold for .dockyard/dockyard.json:\n\(scaffold)")
            }
        }

        static func scaffoldJSON(bundleID: String, name: String, assetName: String) -> String {
            var lines = [
                "{",
                "  \"schemaVersion\": 1,",
                "  \"id\": \"\(bundleID)\",",
                "  \"displayName\": \"\(name)\",",
                "  \"category\": \"TODO\",",
                "  \"summary\": \"TODO\""
            ]
            if let pattern = AssetPatternSuggester.suggest(assetName: assetName) {
                lines[lines.count - 1] += ","
                let escaped = pattern.replacingOccurrences(of: "\\", with: "\\\\")
                lines.append("  \"assetPattern\": \"\(escaped)\"")
            }
            lines.append("}")
            return lines.joined(separator: "\n")
        }
    }
}
