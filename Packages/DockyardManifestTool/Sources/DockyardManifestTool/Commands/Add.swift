import ArgumentParser
import Foundation

extension DockyardManifestTool {

    struct Add: AsyncParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Register a new app repo in the authoring config, scaffolding a ready-to-commit .dockyard/ folder when the repo lacks one."
        )

        @Argument(help: "The GitHub repo as owner/repo.")
        var repository: String

        @Option(name: .shortAndLong, help: "Path to the authoring config JSON.")
        var config: String

        @Option(name: .long, help: "Directory to write the .dockyard/ scaffold into. Defaults to a temp directory.")
        var scaffoldOut: String?

        @Flag(name: .long, help: "Regenerate every .dockyard/ file, overwriting any the destination already has.")
        var forceScaffold = false

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
            // Re-running for a registered repo is a no-op on the config, but still
            // worth doing for the scaffold — that's how a half-finished .dockyard/
            // folder gets completed.
            let alreadyRegistered = authoringConfig.apps
                .contains { $0.github.owner == owner && $0.github.repo == repo }

            let token: String?
            do {
                token = try TokenResolver.resolve()
            } catch {
                BuildRunner.fail("Keychain error: \(error)")
                throw ExitCode(5)
            }
            let api = GitHubAPIClient(token: token)

            var scaffolded: ScaffoldWriter.Result?
            do {
                let release = try await api.latestRelease(owner: owner, repo: repo)
                let asset = try AssetSelector.select(from: release.assets, pattern: assetPattern)
                let missing = try await missingParts(api: api, owner: owner, repo: repo)
                if !missing.isEmpty {
                    scaffolded = try await scaffold(
                        asset: asset,
                        repository: repository,
                        owner: owner,
                        repo: repo,
                        parts: missing
                    )
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

            if alreadyRegistered {
                print("\(repository) is already in \(config); left it unchanged")
            } else {
                let entry = AuthoringEntry(
                    github: AuthoringEntry.GitHub(owner: owner, repo: repo),
                    assetPattern: assetPattern
                )
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    // Carry webApps through: this rewrites the whole file from
                    // decoded state, so anything dropped here is deleted on disk.
                    let updated = AuthoringConfig(
                        apps: authoringConfig.apps + [entry],
                        webApps: authoringConfig.webApps
                    )
                    try encoder.encode(updated).write(to: configURL, options: .atomic)
                } catch {
                    BuildRunner.fail("Failed to update config: \(error)")
                    throw ExitCode(1)
                }
                print("Added \(repository) to \(config)")
            }

            if let scaffolded, !scaffolded.files.isEmpty {
                let todoFiles = scaffolded.files.filter { $0.hasSuffix("dockyard.json") || $0.hasSuffix("about.md") }
                var steps: [String] = []
                if scaffoldOut == nil {
                    steps.append("""
                    Copy the scaffold into \(repository):
                           cp -R \(scaffolded.root.path)/.dockyard <path-to-repo>/
                    """)
                }
                if !todoFiles.isEmpty {
                    steps.append("Fill in the TODO fields in \(todoFiles.joined(separator: " and "))")
                }
                steps.append("Commit and push, then run build (or publish) to add the app to the catalog")

                let numbered = steps.enumerated().map { "  \($0.offset + 1). \($0.element)" }
                print("\nNext steps:\n" + numbered.joined(separator: "\n"))
            }
        }

        /// Probes which parts of `.dockyard/` the repo doesn't publish yet. A
        /// `dockyard.json` that exists but is malformed is a hard error rather
        /// than something to silently scaffold over.
        private func missingParts(api: GitHubAPIClient, owner: String, repo: String) async throws -> ScaffoldWriter.Parts {
            if forceScaffold {
                return .all
            }
            var parts = ScaffoldWriter.Parts(metadata: true, icon: true, about: false, screenshots: false)

            if let file = try await api.getFile(owner: owner, repo: repo, path: ".dockyard/dockyard.json"),
               let downloadURL = file.downloadURL {
                let (data, _) = try await URLSession.shared.data(from: downloadURL)
                _ = try RepoMetadata.decode(data, owner: owner, repo: repo)
                parts.metadata = false
            } else {
                // Fresh onboarding: seed the optional pieces too.
                parts.about = true
                parts.screenshots = true
            }

            if try await api.getFile(owner: owner, repo: repo, path: ".dockyard/AppIcon.png") != nil {
                parts.icon = false
            }
            return parts
        }

        /// Downloads the DMG once to read the bundle identifier, name and icon,
        /// then writes a ready-to-commit `.dockyard/` folder.
        private func scaffold(
            asset: GitHubAsset,
            repository: String,
            owner: String,
            repo: String,
            parts: ScaffoldWriter.Parts
        ) async throws -> ScaffoldWriter.Result {
            print("\(repository) has no complete .dockyard/ folder; downloading \(asset.name) once to inspect it...")
            let (tempURL, _) = try await URLSession.shared.download(from: asset.browserDownloadURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let info: DmgInspector.AppInfo
            do {
                info = try DmgInspector().inspect(dmgAt: tempURL)
            } catch let error as DmgInspectorError {
                BuildRunner.fail("\(error)")
                throw ExitCode(4)
            }

            var parts = parts
            if parts.icon, info.iconPNG == nil {
                parts.icon = false
                BuildRunner.fail("Warning: could not extract an app icon from \(asset.name); add .dockyard/AppIcon.png by hand.")
            }

            let root = try scaffoldOut.map { URL(fileURLWithPath: $0) }
                ?? ScaffoldWriter.temporaryRoot(owner: owner, repo: repo)
            let writer = ScaffoldWriter(
                bundleID: info.bundleID,
                displayName: info.name,
                assetName: asset.name,
                iconPNG: info.iconPNG
            )
            let result = try writer.write(to: root, parts: parts, overwrite: forceScaffold)

            print("Scaffolded into \(result.root.path):")
            for file in result.files {
                print("  \(file)")
            }
            for file in result.skipped {
                print("  \(file) (left alone; already there)")
            }
            return result
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
