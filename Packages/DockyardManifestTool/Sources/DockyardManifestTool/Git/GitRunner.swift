import Foundation

enum GitRunnerError: Error, CustomStringConvertible {
    case commandFailed(command: String, exitCode: Int32, stderr: String)

    var description: String {
        switch self {
        case .commandFailed(let command, let exitCode, let stderr):
            return "git \(command) failed (exit \(exitCode)): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}

/// Minimal wrapper for running git against a specific repository.
struct GitRunner {

    let repoPath: String

    @discardableResult
    func run(_ arguments: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repoPath] + arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errorOutput = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw GitRunnerError.commandFailed(
                command: arguments.joined(separator: " "),
                exitCode: process.terminationStatus,
                stderr: errorOutput.isEmpty ? output : errorOutput
            )
        }
        return output
    }
}
