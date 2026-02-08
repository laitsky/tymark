import Foundation
import AppKit

// MARK: - Tymark Document

public final class TymarkDocument: NSDocument {

    // MARK: - Properties

    public private(set) var markdownContent: String = ""
    public private(set) var documentMetadata: DocumentMetadata

    private var hasUnsavedChanges = false
    private var lastSavedContent: String = ""

    // MARK: - Callbacks

    public var onContentChanged: ((String) -> Void)?
    public var onMetadataChanged: ((DocumentMetadata) -> Void)?
    public var onSaveStateChanged: ((Bool) -> Void)?

    // MARK: - Types

    public struct DocumentMetadata: Codable, Equatable {
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

    // MARK: - Initialization

    public override init() {
        self.documentMetadata = DocumentMetadata()
        super.init()

        // Extract title from file name if available
        if let fileName = fileURL?.deletingPathExtension().lastPathComponent {
            self.documentMetadata.title = fileName
        }
    }

    // MARK: - NSDocument Overrides

    public override class var autosavesInPlace: Bool {
        return true
    }

    public override func makeWindowControllers() {
        // Window controllers are managed by SwiftUI
    }

    public override func data(ofType typeName: String) throws -> Data {
        guard let data = markdownContent.data(using: .utf8) else {
            throw NSError(domain: "TymarkError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not encode document as UTF-8"
            ])
        }
        return data
    }

    public override func read(from data: Data, ofType typeName: String) throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "TymarkError", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not decode document as UTF-8"
            ])
        }

        markdownContent = content
        lastSavedContent = content
        updateMetadata()
    }

    // MARK: - Public API

    public func setContent(_ content: String) {
        guard content != markdownContent else { return }

        markdownContent = content
        hasUnsavedChanges = (content != lastSavedContent)
        updateMetadata()

        onContentChanged?(content)
        onSaveStateChanged?(hasUnsavedChanges)

        updateChangeCount(hasUnsavedChanges ? .changeDone : .changeCleared)
    }

    public func appendContent(_ content: String) {
        setContent(markdownContent + content)
    }

    public func insertContent(_ content: String, at location: Int) {
        var newContent = markdownContent
        let index = newContent.index(newContent.startIndex, offsetBy: min(location, newContent.count))
        newContent.insert(contentsOf: content, at: index)
        setContent(newContent)
    }

    public func replaceContent(in range: NSRange, with replacement: String) {
        let nsString = markdownContent as NSString
        let newContent = nsString.replacingCharacters(in: range, with: replacement)
        setContent(newContent)
    }

    public func saveDocument() {
        save(self)
    }

    @MainActor
    public func saveAs(to url: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!]
        savePanel.nameFieldStringValue = url.lastPathComponent

        savePanel.begin { [weak self] result in
            guard result == .OK, let url = savePanel.url else { return }
            Task { @MainActor in
                self?.save(to: url, ofType: "public.plain-text", for: .saveAsOperation, completionHandler: { _ in })
            }
        }
    }

    public func export(to format: ExportFormat) -> Data? {
        switch format {
        case .html:
            return exportToHTML()
        case .pdf:
            return exportToPDF()
        case .docx:
            return exportToDOCX()
        }
    }

    public func extractTitle() -> String? {
        // Try to extract title from first heading
        let lines = markdownContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2))
            }
        }

        // Fall back to file name
        return fileURL?.deletingPathExtension().lastPathComponent
    }

    public func extractPreview() -> String {
        // Get first few paragraphs for preview
        let lines = markdownContent.components(separatedBy: .newlines)
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

    // MARK: - Private Methods

    private func updateMetadata() {
        var metadata = documentMetadata

        // Update word count
        let words = markdownContent.split(separator: " ")
        metadata.wordCount = words.count

        // Update character count
        metadata.characterCount = markdownContent.count

        // Update modified time
        metadata.modifiedAt = Date()

        // Try to extract title from first heading
        if metadata.title == nil {
            metadata.title = extractTitle()
        }

        documentMetadata = metadata
        onMetadataChanged?(metadata)
    }

    private func exportToHTML() -> Data? {
        // Simple markdown to HTML conversion
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <title>\(documentMetadata.title ?? "Untitled")</title>
        <style>
        body { font-family: -apple-system, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1, h2, h3, h4, h5, h6 { color: #333; }
        pre { background: #f4f4f4; padding: 10px; border-radius: 4px; }
        blockquote { border-left: 4px solid #ddd; margin: 0; padding-left: 16px; color: #666; }
        a { color: #0066cc; }
        </style>
        </head>
        <body>
        """

        // Convert markdown to HTML (simplified)
        let lines = markdownContent.components(separatedBy: .newlines)
        var inCodeBlock = false

        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    html += "</code></pre>\n"
                    inCodeBlock = false
                } else {
                    html += "<pre><code>\n"
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                html += line.htmlEscaped() + "\n"
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("# ") {
                let content = String(trimmed.dropFirst(2)).htmlEscaped()
                html += "<h1>\(content)</h1>\n"
            } else if trimmed.hasPrefix("## ") {
                let content = String(trimmed.dropFirst(3)).htmlEscaped()
                html += "<h2>\(content)</h2>\n"
            } else if trimmed.hasPrefix("### ") {
                let content = String(trimmed.dropFirst(4)).htmlEscaped()
                html += "<h3>\(content)</h3>\n"
            } else if trimmed.hasPrefix("> ") {
                let content = String(trimmed.dropFirst(2)).htmlEscaped()
                html += "<blockquote>\(content)</blockquote>\n"
            } else if trimmed.isEmpty {
                html += "<p></p>\n"
            } else {
                let content = trimmed.htmlEscaped()
                    .replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
                    .replacingOccurrences(of: "\\*\\*([^\\*]+)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
                    .replacingOccurrences(of: "\\*([^\\*]+)\\*", with: "<em>$1</em>", options: .regularExpression)
                html += "<p>\(content)</p>\n"
            }
        }

        html += "</body>\n</html>"

        return html.data(using: .utf8)
    }

    private func exportToPDF() -> Data? {
        // PDF export would require more complex implementation
        // For now, return nil
        return nil
    }

    private func exportToDOCX() -> Data? {
        // DOCX export would require more complex implementation
        // For now, return nil
        return nil
    }

    // MARK: - NSDocument Save/Restore

    @MainActor
    public override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping ((any Error)?) -> Void) {
        super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)

        if saveOperation == .saveOperation || saveOperation == .saveAsOperation {
            lastSavedContent = markdownContent
            hasUnsavedChanges = false
            onSaveStateChanged?(false)
        }
    }

    public override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)

        if let content = coder.decodeObject(forKey: "markdownContent") as? String {
            markdownContent = content
            onContentChanged?(content)
        }

        if let metadataData = coder.decodeObject(forKey: "documentMetadata") as? Data,
           let metadata = try? JSONDecoder().decode(DocumentMetadata.self, from: metadataData) {
            documentMetadata = metadata
            onMetadataChanged?(metadata)
        }
    }

    public override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(markdownContent, forKey: "markdownContent")

        if let metadataData = try? JSONEncoder().encode(documentMetadata) {
            coder.encode(metadataData, forKey: "documentMetadata")
        }
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

// MARK: - String Extensions

extension String {
    func htmlEscaped() -> String {
        return self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
