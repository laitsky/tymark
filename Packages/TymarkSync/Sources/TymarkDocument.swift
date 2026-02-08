import Foundation

// MARK: - Document Metadata

/// Metadata associated with a Tymark markdown document.
public struct DocumentMetadata: Codable, Equatable, Sendable {
    public var title: String?
    public var author: String?
    public var createdAt: Date
    public var modifiedAt: Date
    public var tags: [String]
    public var wordCount: Int
    public var characterCount: Int

    public init(
        title: String? = nil,
        author: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        tags: [String] = [],
        wordCount: Int = 0,
        characterCount: Int = 0
    ) {
        self.title = title
        self.author = author
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
        self.wordCount = wordCount
        self.characterCount = characterCount
    }
}

// MARK: - Export Format

public enum ExportFormat: String, CaseIterable {
    case html = "HTML"
    case pdf = "PDF"
    case docx = "DOCX"

    public var fileExtension: String {
        switch self {
        case .html: return "html"
        case .pdf: return "pdf"
        case .docx: return "docx"
        }
    }

    public var mimeType: String {
        switch self {
        case .html: return "text/html"
        case .pdf: return "application/pdf"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        }
    }
}

// MARK: - Content Extraction Helpers

/// Utility functions for extracting information from markdown content.
public enum MarkdownContentHelpers {

    /// Extract the first `# Heading` as the document title.
    public static func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2))
            }
        }
        return nil
    }

    /// Extract all headings from the content.
    public static func extractHeadings(from content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                return trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            }
            return nil
        }
    }

    /// Extract a short preview from the content (first 3 non-heading, non-empty lines).
    public static func extractPreview(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var previewLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("---") { continue }

            previewLines.append(trimmed)

            if previewLines.count >= 3 {
                break
            }
        }

        return previewLines.joined(separator: " ")
    }
}
