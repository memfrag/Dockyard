import Foundation
import os

public protocol CodesignVerifying: Sendable {
    func verify(_ appURL: URL) async throws
}

public struct CodesignVerifier: CodesignVerifying {

    public init() {}

    public func verify(_ appURL: URL) async throws {
        let codesignResult = try await ProcessRunner.run(
            executable: "/usr/bin/codesign",
            arguments: ["--verify", "--deep", "--strict", appURL.path]
        )
        if !codesignResult.isSuccess {
            let stderr = codesignResult.stderrString
            Logger.verifier.error("codesign failed: \(stderr, privacy: .public)")
            throw EngineError.verificationFailed(tool: .codesign, stderr: stderr)
        }

        let spctlResult = try await ProcessRunner.run(
            executable: "/usr/sbin/spctl",
            arguments: ["--assess", "--type", "execute", appURL.path]
        )
        if !spctlResult.isSuccess {
            let stderr = spctlResult.stderrString
            Logger.verifier.error("spctl failed: \(stderr, privacy: .public)")
            throw EngineError.verificationFailed(tool: .spctl, stderr: stderr)
        }
    }
}
