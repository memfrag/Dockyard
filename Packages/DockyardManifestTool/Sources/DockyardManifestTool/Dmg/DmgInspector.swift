import AppKit
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

/// Mounts a DMG read-only, reads the first `.app` bundle's Info.plist and icon,
/// and detaches again. Used by the `add` command to discover an app's bundle
/// identifier, name and icon when the repo has no `.dockyard/` folder yet.
struct DmgInspector {

    /// Pixel size of the extracted `AppIcon.png` — 256pt @2x, comfortably above
    /// every place Dockyard renders a catalog icon.
    static let iconPixelSize = 512

    struct AppInfo {
        let bundleID: String
        let name: String
        /// PNG data for `.dockyard/AppIcon.png`, or nil when no icon could be extracted.
        let iconPNG: Data?
    }

    func inspect(dmgAt url: URL) throws -> AppInfo {
        let mountPoint = try attach(url)
        defer { detach(mountPoint) }

        let contents = try FileManager.default.contentsOfDirectory(atPath: mountPoint)
        guard let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
            throw DmgInspectorError.noAppBundle(mountPoint: mountPoint)
        }

        let appURL = URL(fileURLWithPath: mountPoint).appending(path: appName)
        let plistURL = appURL.appending(path: "Contents/Info.plist")
        let data = try Data(contentsOf: plistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw DmgInspectorError.missingBundleID(app: appName)
        }
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? String(appName.dropLast(".app".count))
        return AppInfo(bundleID: bundleID, name: name, iconPNG: iconPNG(appURL: appURL, plist: plist))
    }

    // MARK: - Icon extraction

    /// Extracts an app bundle's icon as PNG, reading its Info.plist for the icon name.
    func iconPNG(appAt appURL: URL) -> Data? {
        let plistURL = appURL.appending(path: "Contents/Info.plist")
        let plist = (try? Data(contentsOf: plistURL))
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
        return iconPNG(appURL: appURL, plist: plist ?? [:])
    }

    /// Best-effort: converts the bundle's `.icns` with `sips`, falling back to the
    /// icon the Finder would show (which also covers apps whose icon only exists
    /// inside a compiled `Assets.car`).
    private func iconPNG(appURL: URL, plist: [String: Any]) -> Data? {
        if let icns = icnsURL(appURL: appURL, plist: plist), let png = convertToPNG(icns) {
            return png
        }
        return renderWorkspaceIcon(appURL: appURL)
    }

    private func icnsURL(appURL: URL, plist: [String: Any]) -> URL? {
        let resources = appURL.appending(path: "Contents/Resources")
        let fileManager = FileManager.default

        if let iconFile = plist["CFBundleIconFile"] as? String, !iconFile.isEmpty {
            let named = iconFile.hasSuffix(".icns") ? iconFile : iconFile + ".icns"
            let url = resources.appending(path: named)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }

        let icns = ((try? fileManager.contentsOfDirectory(atPath: resources.path)) ?? [])
            .filter { $0.hasSuffix(".icns") }
            .sorted()
        return (icns.first { $0 == "AppIcon.icns" } ?? icns.first).map { resources.appending(path: $0) }
    }

    private func convertToPNG(_ icns: URL) -> Data? {
        let output = FileManager.default.temporaryDirectory
            .appending(path: "dockyard-icon-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: output) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = [
            "-s", "format", "png",
            "-Z", "\(Self.iconPixelSize)",
            icns.path,
            "--out", output.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return try? Data(contentsOf: output)
    }

    private func renderWorkspaceIcon(appURL: URL) -> Data? {
        let size = Self.iconPixelSize
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        rep.size = NSSize(width: size, height: size)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        icon.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        return rep.representation(using: .png, properties: [:])
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
