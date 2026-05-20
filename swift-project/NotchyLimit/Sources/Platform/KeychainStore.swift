import Foundation
import Security
import os.log

private let logger = Logger(subsystem: "com.notchylimit.NotchyLimit", category: "Keychain")

/// Tiny Keychain wrapper for `kSecClassGenericPassword` items.
/// Used to store provider credentials (e.g. Claude session cookie).
///
/// Security posture:
///  - `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — readable only while
///    the screen is unlocked; never leaves the device via iCloud backup.
///  - `SecAccessCreate` with the current process as the sole trusted
///    application — any other process attempting to read the item will
///    trigger a macOS user-confirmation prompt.
public final class KeychainStore {
    private let service: String
    public init(service: String) { self.service = service }

    public func set(account: String, data: Data) {
        let label = "\(service) — \(account)"
        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String:   label,
        ]
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String]     = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        // Bind the item to this application.
        // SecTrustedApplicationCreateFromPath(nil, ...) = the currently running
        // binary. Other processes require user confirmation to access the item.
        // Note: SecAccessCreate is deprecated (macOS 10.10) but remains the
        // only reliable ACL mechanism for non-sandboxed apps on macOS 12+.
        if let access = makeAppBoundAccess(label: label) {
            query[kSecAttrAccess as String] = access
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Keychain write failed: OSStatus \(status, privacy: .public)")
        }
    }

    public func get(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    public func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Private

    private func makeAppBoundAccess(label: String) -> SecAccess? {
        var selfRef: SecTrustedApplication?
        guard SecTrustedApplicationCreateFromPath(nil, &selfRef) == errSecSuccess,
              let trusted = selfRef else {
            logger.warning("Could not create trusted-application reference — item will use default ACL")
            return nil
        }
        var access: SecAccess?
        let status = SecAccessCreate(label as CFString, [trusted] as CFArray, &access)
        guard status == errSecSuccess else {
            logger.warning("SecAccessCreate failed: OSStatus \(status, privacy: .public)")
            return nil
        }
        return access
    }
}
