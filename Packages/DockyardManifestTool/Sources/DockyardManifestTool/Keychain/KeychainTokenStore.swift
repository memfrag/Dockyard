import Foundation
import Security

enum KeychainTokenStoreError: Error, CustomStringConvertible {
    case osStatus(OSStatus, operation: String)
    case unexpectedData

    var description: String {
        switch self {
        case .osStatus(let status, let operation):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Keychain \(operation) failed: \(message)"
        case .unexpectedData:
            return "Keychain returned unexpected data format"
        }
    }
}

struct KeychainTokenStore {

    static let service = "io.apparata.dockyard-manifest-tool"
    static let account = "github-token"

    func load() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, $0)
        }

        if status == errSecItemNotFound { return nil }
        if status != errSecSuccess {
            throw KeychainTokenStoreError.osStatus(status, operation: "load")
        }
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainTokenStoreError.unexpectedData
        }
        return token
    }

    func save(_ token: String) throws {
        let data = Data(token.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]

        let updateAttrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw KeychainTokenStoreError.osStatus(updateStatus, operation: "update")
        }

        var addAttrs = baseQuery
        addAttrs[kSecValueData as String] = data
        let addStatus = SecItemAdd(addAttrs as CFDictionary, nil)
        if addStatus != errSecSuccess {
            throw KeychainTokenStoreError.osStatus(addStatus, operation: "add")
        }
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainTokenStoreError.osStatus(status, operation: "delete")
        }
    }
}
