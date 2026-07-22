import ArgumentParser
import Foundation

extension DockyardManifestTool {

    struct Publish: AsyncParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "publish",
            abstract: "Build the manifest and commit + push it to the manifest repo in one step."
        )

        @Option(name: .long, help: "Path to the DockyardManifest repo checkout (contains dockyard.config.json and manifest.json).")
        var manifestRepo: String

        @Flag(name: .long, help: "Build and print the change summary without committing.")
        var dryRun: Bool = false

        @Flag(inversion: .prefixedNo, help: "Embed dmgSHA256 hashes (GitHub digest or cached hash when possible; downloads only genuinely new releases).")
        var hash: Bool = true

        @Flag(name: .long, help: "Ignore hashes cached in the existing manifest and recompute them.")
        var forceHash: Bool = false

        @Option(name: .shortAndLong, help: "Commit message. Auto-generated from the changes when omitted.")
        var message: String?

        mutating func run() async throws {
            let repoURL = URL(fileURLWithPath: manifestRepo)
            let git = GitRunner(repoPath: repoURL.path)

            // Refuse up front if unrelated changes are staged, so an in-progress
            // config/editorial edit can't be swept into the manifest commit.
            let staged: String
            do {
                staged = try git.run("diff", "--cached", "--name-only")
            } catch {
                BuildRunner.fail("\(error)")
                throw ExitCode(7)
            }
            let unrelated = staged
                .split(separator: "\n")
                .map(String.init)
                .filter { $0 != "manifest.json" }
            guard unrelated.isEmpty else {
                BuildRunner.fail("Refusing to publish: unrelated staged changes in \(manifestRepo): \(unrelated.joined(separator: ", "))")
                throw ExitCode(7)
            }

            let result = try await BuildRunner.run(
                configPath: repoURL.appending(path: "dockyard.config.json").path,
                outputPath: repoURL.appending(path: "manifest.json").path,
                hash: hash,
                forceHash: forceHash
            )

            // Publish whenever the manifest differs from what's committed —
            // not just when this build changed the file — so a manifest left
            // dirty by an earlier `build` run still gets pushed.
            let dirty: String
            do {
                dirty = try git.run("status", "--porcelain", "--", "manifest.json")
            } catch {
                BuildRunner.fail("\(error)")
                throw ExitCode(7)
            }
            guard !dirty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("Manifest is up to date (\(result.manifest.apps.count) apps); nothing to publish")
                return
            }

            // Diff against the committed manifest so the summary and commit
            // message describe what this push actually changes.
            let committed = (try? git.run("show", "HEAD:manifest.json"))
                .map { PreviousManifest.load(from: Data($0.utf8)) }
                ?? PreviousManifest()
            let diff = ManifestDiff.between(previous: committed, new: result.manifest)
            print("Changes:")
            for line in diff.summaryLines {
                print("  \(line)")
            }
            if dryRun {
                print("Dry run; not committing")
                return
            }

            let commitMessage = message ?? diff.commitMessage
            do {
                try git.run("add", "manifest.json")
                try git.run("commit", "-m", commitMessage)
                try git.run("push")
            } catch {
                BuildRunner.fail("\(error)")
                throw ExitCode(7)
            }
            print("Published: \(commitMessage)")
        }
    }
}
