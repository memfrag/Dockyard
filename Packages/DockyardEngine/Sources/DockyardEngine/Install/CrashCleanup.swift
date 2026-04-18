import Foundation
import os

struct CrashCleanup: Sendable {

    let mounter: DMGMounting
    let tempRoot: URL

    init(mounter: DMGMounting = DMGMounter(), tempRoot: URL = CrashCleanup.defaultTempRoot) {
        self.mounter = mounter
        self.tempRoot = tempRoot
    }

    static var defaultTempRoot: URL {
        FileManager.default.temporaryDirectory.appending(path: "dockyard")
    }

    /// Detach stale marker-prefixed mounts and purge the temp directory.
    func run() async {
        let stale = await mounter.listDockyardMounts()
        for handle in stale {
            do {
                try await mounter.detach(handle)
                Logger.engine.info("Detached stale mount \(handle.mountPoint.path, privacy: .public)")
            } catch {
                Logger.engine.warning("Could not detach stale mount \(handle.mountPoint.path, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        if FileManager.default.fileExists(atPath: tempRoot.path) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: tempRoot,
                    includingPropertiesForKeys: nil
                )
                for item in contents {
                    try? FileManager.default.removeItem(at: item)
                }
            } catch {
                Logger.engine.warning("Could not purge temp: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
