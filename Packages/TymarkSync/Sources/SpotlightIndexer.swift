import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

// MARK: - Spotlight Indexer

/// Indexes markdown documents into CoreSpotlight for system-wide search.
/// Extracts titles, headings, full text content, and metadata.
@MainActor
public final class SpotlightIndexer {

    // MARK: - Properties

    private let searchableIndex: CSSearchableIndex
    private let domainIdentifier = "com.tymark.documents"

    // MARK: - Initialization

    public init(index: CSSearchableIndex = .default()) {
        self.searchableIndex = index
    }

    // MARK: - Public API

    /// Index a single markdown document.
    public func indexDocument(
        at url: URL,
        content: String,
        title: String?,
        modificationDate: Date = Date()
    ) {
        let attributeSet = buildAttributeSet(
            url: url,
            content: content,
            title: title,
            modificationDate: modificationDate
        )

        let uniqueID = url.absoluteString
        let item = CSSearchableItem(
            uniqueIdentifier: uniqueID,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        // Keep indexed for 30 days
        item.expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)

        searchableIndex.indexSearchableItems([item]) { error in
            if let error {
                print("Spotlight indexing failed for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    /// Index multiple markdown documents in batch.
    public func indexDocuments(_ documents: [(url: URL, content: String, title: String?)]) {
        let items = documents.map { doc in
            let attributeSet = buildAttributeSet(
                url: doc.url,
                content: doc.content,
                title: doc.title,
                modificationDate: Date()
            )

            let item = CSSearchableItem(
                uniqueIdentifier: doc.url.absoluteString,
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
            item.expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
            return item
        }

        searchableIndex.indexSearchableItems(items) { error in
            if let error {
                print("Batch Spotlight indexing failed: \(error.localizedDescription)")
            }
        }
    }

    /// Remove a document from the Spotlight index.
    public func removeDocument(at url: URL) {
        searchableIndex.deleteSearchableItems(withIdentifiers: [url.absoluteString]) { error in
            if let error {
                print("Spotlight removal failed: \(error.localizedDescription)")
            }
        }
    }

    /// Remove all Tymark documents from the Spotlight index.
    public func removeAllDocuments() {
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error {
                print("Spotlight removal failed: \(error.localizedDescription)")
            }
        }
    }

    /// Re-index all documents in a directory.
    public func reindexDirectory(at directoryURL: URL) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let documents = Self.collectDocuments(in: directoryURL)
            await MainActor.run { [weak self, documents] in
                self?.indexDocuments(documents)
            }
        }
    }

    // MARK: - Private Methods

    private func buildAttributeSet(
        url: URL,
        content: String,
        title: String?,
        modificationDate: Date
    ) -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .plainText)

        // Basic metadata
        attributeSet.title = title ?? url.deletingPathExtension().lastPathComponent
        attributeSet.contentDescription = Self.extractPreview(from: content)
        attributeSet.textContent = Self.stripMarkdownSyntax(content)
        attributeSet.contentURL = url
        attributeSet.contentModificationDate = modificationDate
        attributeSet.contentCreationDate = modificationDate

        // File metadata
        attributeSet.displayName = url.deletingPathExtension().lastPathComponent
        attributeSet.path = url.path
        attributeSet.contentType = UTType.plainText.identifier

        // Keywords from headings
        let headings = Self.extractHeadings(from: content)
        attributeSet.keywords = headings

        // Author if available from YAML front matter
        if let author = Self.extractFrontMatterValue(key: "author", from: content) {
            attributeSet.authorNames = [author]
        }

        return attributeSet
    }

    // MARK: - Content Extraction (static for reuse)

    nonisolated private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    nonisolated private static func collectDocuments(in directoryURL: URL) -> [(url: URL, content: String, title: String?)] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var documents: [(url: URL, content: String, title: String?)] = []
        for case let fileURL as URL in enumerator {
            guard markdownExtensions.contains(fileURL.pathExtension.lowercased()) else {
                continue
            }
            guard let data = try? Data(contentsOf: fileURL),
                  let content = String(data: data, encoding: .utf8) else {
                continue
            }
            documents.append((url: fileURL, content: content, title: extractTitle(from: content)))
        }
        return documents
    }

    nonisolated static func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2))
            }
        }
        return nil
    }

    nonisolated static func extractHeadings(from content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                return trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            }
            return nil
        }
    }

    nonisolated static func extractPreview(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var previewLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("---") else { continue }
            previewLines.append(trimmed)
            if previewLines.count >= 3 { break }
        }

        let preview = previewLines.joined(separator: " ")
        if preview.count > 300 {
            return String(preview.prefix(300)) + "..."
        }
        return preview
    }

    nonisolated static func stripMarkdownSyntax(_ content: String) -> String {
        var stripped = content
        // Remove headings markers
        stripped = stripped.replacingOccurrences(of: "#{1,6}\\s+", with: "", options: .regularExpression)
        // Remove emphasis markers
        stripped = stripped.replacingOccurrences(of: "\\*+([^*]+)\\*+", with: "$1", options: .regularExpression)
        stripped = stripped.replacingOccurrences(of: "_+([^_]+)_+", with: "$1", options: .regularExpression)
        // Remove link syntax
        stripped = stripped.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        // Remove image syntax
        stripped = stripped.replacingOccurrences(of: "!\\[([^\\]]*?)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        // Remove code fences
        stripped = stripped.replacingOccurrences(of: "```[^`]*```", with: "", options: .regularExpression)
        // Remove inline code
        stripped = stripped.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
        return stripped
    }

    nonisolated static func extractFrontMatterValue(key: String, from content: String) -> String? {
        guard content.hasPrefix("---") else { return nil }

        let lines = content.components(separatedBy: .newlines)
        var inFrontMatter = false

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                if inFrontMatter {
                    break // End of front matter
                }
                inFrontMatter = true
                continue
            }

            if inFrontMatter {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2,
                   parts[0].trimmingCharacters(in: .whitespaces).lowercased() == key.lowercased() {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return nil
    }
}
