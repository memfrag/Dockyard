import ArgumentParser
import Foundation

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

        @Flag(inversion: .prefixedNo, help: "Embed dmgSHA256 hashes (GitHub digest or cached hash when possible; downloads only genuinely new releases).")
        var hash: Bool = true

        @Flag(name: .long, help: "Ignore hashes cached in the existing manifest and recompute them.")
        var forceHash: Bool = false

        mutating func run() async throws {
            let result = try await BuildRunner.run(
                configPath: config,
                outputPath: output,
                hash: hash,
                forceHash: forceHash
            )
            if result.wrote {
                print("Wrote \(output) (\(result.manifest.apps.count) apps)")
            } else {
                print("No changes; \(output) is up to date (\(result.manifest.apps.count) apps)")
            }
        }
    }
}
