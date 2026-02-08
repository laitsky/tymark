import Foundation
import Combine

// MARK: - Document Version Manager

/// Manages document version history using NSFileVersion, providing
/// browse, restore, and cleanup capabilities.
@MainActor
public final class DocumentVersionManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var versions: [DocumentVersion] = []
    @Published public private(set) var isLoadingVersions: Bool = false

    // MARK: - Types

    public struct DocumentVersion: Identifiable, Equatable {
        public let id: UUID
        public let fileVersion: NSFileVersion
        public let modificationDate: Date
        public let localizedName: String?
        public let isCurrentVersion: Bool
        public let contentPreview: String?

        public init(
            fileVersion: NSFileVersion,
            isCurrentVersion: Bool = false,
            contentPreview: String? = nil
        ) {
            self.id = UUID()
            self.fileVersion = fileVersion
            self.modificationDate = fileVersion.modificationDate ?? Date()
            self.localizedName = fileVersion.localizedName
            self.isCurrentVersion = isCurrentVersion
            self.contentPreview = contentPreview
        }

        public static func == (lhs: DocumentVersion, rhs: DocumentVersion) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Callbacks

    public var onVersionRestored: ((URL) -> Void)?
    public var onError: ((Error) -> Void)?

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Load all versions for a document at the given URL.
    public func loadVersions(for url: URL) {
        isLoadingVersions = true

        Task.detached { [weak self] in
            let fileVersions = NSFileVersion.otherVersionsOfItem(at: url) ?? []
            let currentVersion = NSFileVersion.currentVersionOfItem(at: url)

            var documentVersions: [DocumentVersion] = []

            // Add current version first
            if let current = currentVersion {
                let preview = self?.loadContentPreview(from: url)
                documentVersions.append(
                    DocumentVersion(
                        fileVersion: current,
                        isCurrentVersion: true,
                        contentPreview: preview
                    )
                )
            }

            // Add other versions sorted by date (newest first)
            let sorted = fileVersions.sorted {
                ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
            }

            for version in sorted {
                let preview = self?.loadContentPreview(from: version.url)
                documentVersions.append(
                    DocumentVersion(
                        fileVersion: version,
                        contentPreview: preview
                    )
                )
            }

            await MainActor.run { [weak self] in
                self?.versions = documentVersions
                self?.isLoadingVersions = false
            }
        }
    }

    /// Restore a specific version, replacing the current document content.
    public func restoreVersion(_ version: DocumentVersion, for url: URL) {
        do {
            try version.fileVersion.replaceItem(at: url, options: .byMoving)
            onVersionRestored?(url)
            // Reload versions after restore
            loadVersions(for: url)
        } catch {
            onError?(error)
        }
    }

    /// Remove a specific version from history.
    public func removeVersion(_ version: DocumentVersion) {
        guard !version.isCurrentVersion else { return }

        do {
            try version.fileVersion.remove()
            versions.removeAll { $0.id == version.id }
        } catch {
            onError?(error)
        }
    }

    /// Remove all old versions for a document, keeping only the current one.
    public func removeAllOldVersions(for url: URL) {
        do {
            try NSFileVersion.removeOtherVersionsOfItem(at: url)
            loadVersions(for: url)
        } catch {
            onError?(error)
        }
    }

    /// Get the total count of versions for a document.
    public func versionCount(for url: URL) -> Int {
        return (NSFileVersion.otherVersionsOfItem(at: url)?.count ?? 0) + 1
    }

    // MARK: - Private Methods

    private nonisolated func loadContentPreview(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Return first few non-empty, non-heading lines as preview
        let lines = content.components(separatedBy: .newlines)
        var previewLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("---") else { continue }

            previewLines.append(trimmed)
            if previewLines.count >= 2 { break }
        }

        let preview = previewLines.joined(separator: " ")
        // Truncate long previews
        if preview.count > 200 {
            return String(preview.prefix(200)) + "..."
        }
        return preview.isEmpty ? nil : preview
    }
}
