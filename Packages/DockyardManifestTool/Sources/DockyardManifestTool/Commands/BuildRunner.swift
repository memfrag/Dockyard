import ArgumentParser
import DockyardEngine
import Foundation

struct BuildResult {
    let manifest: CatalogManifest
    let previous: PreviousManifest
    let wrote: Bool
}

/// Shared build pipeline for the `build` and `publish` commands: load config,
/// resolve token, build the manifest (reusing hashes from the existing
/// output), and write it. Errors are printed to stderr and mapped to the
/// tool's documented exit codes.
enum BuildRunner {

    static func run(
        configPath: String,
        outputPath: String,
        hash: Bool,
        forceHash: Bool
    ) async throws -> BuildResult {
        let configURL = URL(fileURLWithPath: configPath)
        let outputURL = URL(fileURLWithPath: outputPath)

        let authoringConfig: AuthoringConfig
        do {
            authoringConfig = try AuthoringConfig.load(from: configURL)
        } catch {
            fail("Failed to read config: \(error)")
            throw ExitCode(1)
        }

        let token: String?
        do {
            token = try TokenResolver.resolve()
        } catch {
            fail("Keychain error: \(error)")
            throw ExitCode(5)
        }

        let previous = PreviousManifest.load(from: outputURL)
        let api = GitHubAPIClient(token: token)
        let hasher: RemoteHasher? = hash ? RemoteHasher() : nil
        let builder = ManifestBuilder(api: api, hasher: hasher, previous: previous, forceHash: forceHash)

        let manifest: CatalogManifest
        do {
            manifest = try await builder.build(config: authoringConfig)
        } catch let error as GitHubAPIError {
            fail("\(error)")
            throw ExitCode(2)
        } catch let error as AssetSelectorError {
            fail("\(error)")
            throw ExitCode(3)
        } catch let error as MetadataError {
            fail("\(error)")
            throw ExitCode(6)
        } catch let error as RepoMetadataError {
            fail("\(error)")
            throw ExitCode(6)
        } catch {
            fail("Network or builder error: \(error)")
            throw ExitCode(4)
        }

        let wrote: Bool
        do {
            wrote = try ManifestWriter.write(manifest, to: outputURL)
        } catch {
            fail("Write failed: \(error)")
            throw ExitCode(1)
        }
        return BuildResult(manifest: manifest, previous: previous, wrote: wrote)
    }

    static func fail(_ message: String) {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
    }
}
