import ArgumentParser
import Foundation

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
