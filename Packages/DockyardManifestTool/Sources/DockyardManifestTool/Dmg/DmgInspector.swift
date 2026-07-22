import Foundation

enum DmgInspectorError: Error, CustomStringConvertible {
    case hdiutilFailed(String)
    case noMountPoint
    case noAppBundle(mountPoint: String)
    case missingBundleID(app: String)

    var description: String {
        switch self {
        case .hdiutilFailed(let output):
            return "hdiutil failed: \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .noMountPoint:
            return "hdiutil attach produced no mount point"
        case .noAppBundle(let mountPoint):
            return "No .app bundle found in mounted DMG at \(mountPoint)"
        case .missingBundleID(let app):
            return "\(app) has no CFBundleIdentifier in its Info.plist"
        }
    }
}

/// Mounts a DMG read-only, reads the first `.app` bundle's Info.plist, and
/// detaches again. Used by the `add` command to discover an app's bundle
/// identifier and name when the repo has no `.dockyard/dockyard.json` yet.
struct DmgInspector {

    struct AppInfo {
        let bundleID: String
        let name: String
    }

    func inspect(dmgAt url: URL) throws -> AppInfo {
        let mountPoint = try attach(url)
        defer { detach(mountPoint) }

        let contents = try FileManager.default.contentsOfDirectory(atPath: mountPoint)
        guard let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
            throw DmgInspectorError.noAppBundle(mountPoint: mountPoint)
        }

        let plistURL = URL(fileURLWithPath: mountPoint)
            .appending(path: appName)
            .appending(path: "Contents/Info.plist")
        let data = try Data(contentsOf: plistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw DmgInspectorError.missingBundleID(app: appName)
        }
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? String(appName.dropLast(".app".count))
        return AppInfo(bundleID: bundleID, name: name)
    }

    private func attach(_ url: URL) throws -> String {
        let output = try runHdiutil([
            "attach", url.path,
            "-nobrowse", "-readonly",
            "-mountrandom", NSTemporaryDirectory(),
            "-plist"
        ])
        guard let plist = try? PropertyListSerialization.propertyList(from: Data(output.utf8), format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mountPoint = entities.compactMap({ $0["mount-point"] as? String }).first else {
            throw DmgInspectorError.noMountPoint
        }
        return mountPoint
    }

    private func detach(_ mountPoint: String) {
        _ = try? runHdiutil(["detach", mountPoint, "-quiet"])
    }

    private func runHdiutil(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            let errorOutput = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw DmgInspectorError.hdiutilFailed(errorOutput.isEmpty ? output : errorOutput)
        }
        return output
    }
}
