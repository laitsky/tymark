import Foundation
import Security

// MARK: - AI Configuration

/// Configuration for the AI writing assistant, including engine selection
/// and API key management via Keychain.
@MainActor
public final class AIConfiguration: ObservableObject {

    @Published public var selectedEngine: AIEngineType {
        didSet { UserDefaults.standard.set(selectedEngine.rawValue, forKey: "aiSelectedEngine") }
    }

    @Published public var cloudModel: String {
        didSet { UserDefaults.standard.set(cloudModel, forKey: "aiCloudModel") }
    }

    public init() {
        let savedEngine = UserDefaults.standard.string(forKey: "aiSelectedEngine") ?? "local"
        self.selectedEngine = AIEngineType(rawValue: savedEngine) ?? .local
        self.cloudModel = UserDefaults.standard.string(forKey: "aiCloudModel") ?? "claude-sonnet-4-5-20250929"
    }

    // MARK: - API Key (Keychain)

    private static let keychainService = "com.tymark.ai"
    private static let keychainAccount = "anthropic-api-key"

    public var apiKey: String? {
        get { Self.retrieveFromKeychain() }
        set {
            if let key = newValue {
                Self.storeInKeychain(key)
            } else {
                Self.deleteFromKeychain()
            }
            objectWillChange.send()
        }
    }

    public var hasAPIKey: Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }

    // MARK: - Keychain Operations

    @discardableResult
    private static func storeInKeychain(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        deleteFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[TymarkAI] Keychain store failed: \(status)")
        }
        return status == errSecSuccess
    }

    private static func retrieveFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private static func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Available Models

    public static let availableModels = [
        "claude-sonnet-4-5-20250929",
        "claude-haiku-4-5-20251001",
        "claude-opus-4-6"
    ]
}
