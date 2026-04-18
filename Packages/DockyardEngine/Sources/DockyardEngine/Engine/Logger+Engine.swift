import Foundation
import os

extension Logger {
    static let engine = Logger(subsystem: "io.apparata.dockyard.engine", category: "engine")
    static let downloader = Logger(subsystem: "io.apparata.dockyard.engine", category: "downloader")
    static let installer = Logger(subsystem: "io.apparata.dockyard.engine", category: "installer")
    static let mounter = Logger(subsystem: "io.apparata.dockyard.engine", category: "mounter")
    static let verifier = Logger(subsystem: "io.apparata.dockyard.engine", category: "verifier")
    static let catalog = Logger(subsystem: "io.apparata.dockyard.engine", category: "catalog")
    static let tracking = Logger(subsystem: "io.apparata.dockyard.engine", category: "tracking")
}
