import Foundation

// MARK: - AI Privacy Manager

/// Manages privacy settings for AI features, including local-only mode
/// and per-document cloud consent tracking.
@MainActor
public final class AIPrivacyManager: ObservableObject {

    @Published public var isLocalOnly: Bool {
        didSet { UserDefaults.standard.set(isLocalOnly, forKey: "aiLocalOnly") }
    }

    @Published public var cloudConsentGiven: Bool {
        didSet { UserDefaults.standard.set(cloudConsentGiven, forKey: "aiCloudConsent") }
    }

    /// Documents that have been explicitly approved for cloud AI processing.
    private var approvedDocuments: Set<String> = []

    public init() {
        self.isLocalOnly = UserDefaults.standard.object(forKey: "aiLocalOnly") as? Bool ?? true
        self.cloudConsentGiven = UserDefaults.standard.bool(forKey: "aiCloudConsent")

        if let saved = UserDefaults.standard.stringArray(forKey: "aiApprovedDocuments") {
            approvedDocuments = Set(saved)
        }
    }

    // MARK: - Cloud Consent

    /// Whether cloud AI can be used for the given document.
    public func canUseCloud(for documentURL: URL?) -> Bool {
        guard !isLocalOnly else { return false }
        guard cloudConsentGiven else { return false }

        if let url = documentURL {
            return approvedDocuments.contains(url.absoluteString)
        }

        return cloudConsentGiven
    }

    /// Records consent for cloud AI processing of a specific document.
    public func approveCloudForDocument(_ url: URL) {
        approvedDocuments.insert(url.absoluteString)
        UserDefaults.standard.set(Array(approvedDocuments), forKey: "aiApprovedDocuments")
    }

    /// Revokes cloud AI consent for a specific document.
    public func revokeCloudForDocument(_ url: URL) {
        approvedDocuments.remove(url.absoluteString)
        UserDefaults.standard.set(Array(approvedDocuments), forKey: "aiApprovedDocuments")
    }

    /// Whether cloud AI is active (not local-only and consent given).
    public var isCloudActive: Bool {
        return !isLocalOnly && cloudConsentGiven
    }
}
