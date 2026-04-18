import Foundation
import os

/// A handle returned by a successful mount, used to detach the same volume later.
public struct MountHandle: Sendable, Equatable {
    public let mountPoint: URL
    public let devEntry: String?
}

public protocol DMGMounting: Sendable {
    func attach(_ dmgURL: URL) async throws -> MountHandle
    func detach(_ handle: MountHandle) async throws
    func listDockyardMounts() async -> [MountHandle]
}

public struct DMGMounter: DMGMounting {

    static let mountPointPrefix = "/tmp/dockyard-mount-"

    public init() {}

    public func attach(_ dmgURL: URL) async throws -> MountHandle {
        let mountPoint = "\(Self.mountPointPrefix)\(UUID().uuidString)"
        let result = try await ProcessRunner.run(
            executable: "/usr/bin/hdiutil",
            arguments: [
                "attach", dmgURL.path,
                "-nobrowse", "-readonly", "-plist",
                "-mountpoint", mountPoint
            ]
        )
        guard result.isSuccess else {
            throw EngineError.mountFailed(stderr: result.stderrString)
        }

        guard let firstMount = Self.firstMountPoint(fromPlist: result.stdout) else {
            throw EngineError.mountFailed(stderr: "Could not parse mount-point from hdiutil output")
        }
        return firstMount
    }

    public func detach(_ handle: MountHandle) async throws {
        let target = handle.devEntry ?? handle.mountPoint.path
        let result = try await ProcessRunner.run(
            executable: "/usr/bin/hdiutil",
            arguments: ["detach", target, "-force"]
        )
        if !result.isSuccess {
            Logger.mounter.warning("hdiutil detach failed for \(target, privacy: .public): \(result.stderrString, privacy: .public)")
        }
    }

    public func listDockyardMounts() async -> [MountHandle] {
        do {
            let result = try await ProcessRunner.run(
                executable: "/usr/bin/hdiutil",
                arguments: ["info", "-plist"]
            )
            guard result.isSuccess else { return [] }
            return Self.dockyardMounts(fromInfoPlist: result.stdout)
        } catch {
            return []
        }
    }

    // MARK: - Plist parsing

    static func firstMountPoint(fromPlist data: Data) -> MountHandle? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            return nil
        }
        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String, !mountPoint.isEmpty {
                let devEntry = entity["dev-entry"] as? String
                return MountHandle(
                    mountPoint: URL(fileURLWithPath: mountPoint),
                    devEntry: devEntry
                )
            }
        }
        return nil
    }

    static func dockyardMounts(fromInfoPlist data: Data) -> [MountHandle] {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let images = plist["images"] as? [[String: Any]] else {
            return []
        }
        var handles: [MountHandle] = []
        for image in images {
            guard let entities = image["system-entities"] as? [[String: Any]] else { continue }
            for entity in entities {
                guard let mountPoint = entity["mount-point"] as? String,
                      mountPoint.hasPrefix(mountPointPrefix) else { continue }
                let devEntry = entity["dev-entry"] as? String
                handles.append(MountHandle(
                    mountPoint: URL(fileURLWithPath: mountPoint),
                    devEntry: devEntry
                ))
            }
        }
        return handles
    }
}
