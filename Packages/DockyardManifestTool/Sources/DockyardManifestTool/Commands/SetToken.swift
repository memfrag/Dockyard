import ArgumentParser
import Foundation

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
