import Foundation

public enum InstallDestination {

    /// `~/Applications`.
    public static var userApplications: URL {
        FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask)[0]
    }

    /// Ensures the destination directory exists, creating it if necessary.
    @discardableResult
    public static func ensure(_ directory: URL = userApplications) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
