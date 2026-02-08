import Foundation
import TymarkParser
import TymarkTheme
import AppKit

// MARK: - Export Protocol

public protocol Exporter {
    func export(document: TymarkDocument, theme: Theme) -> Data?
    var fileExtension: String { get }
    var mimeType: String { get }
}

// MARK: - HTML Exporter

public final class HTMLExporter: Exporter {
    public let fileExtension = "html"
    public let mimeType = "text/html"

    public init() {}

    public func export(document: TymarkDocument, theme: Theme) -> Data? {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <title>Tymark Export</title>
        <style>
        \(generateCSS(theme: theme))
        </style>
        </head>
        <body>
        \(convertToHTML(document.root))
        </body>
        </html>
        """
        return html.data(using: .utf8)
    }

    private func generateCSS(theme: Theme) -> String {
        return """
        body {
            font-family: -apple-system, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            color: \(theme.colors.text.hexString);
            background: \(theme.colors.background.hexString);
        }
        pre {
            background: \(theme.colors.codeBackground.hexString);
            padding: 12px;
            border-radius: 6px;
        }
        blockquote {
            border-left: 4px solid \(theme.colors.quoteBorder.hexString);
            margin: 0;
            padding-left: 16px;
            color: \(theme.colors.quoteText.hexString);
        }
        """
    }

    private func convertToHTML(_ node: TymarkNode) -> String {
        switch node.type {
        case .document:
            return node.children.map(convertToHTML).joined()
        case .paragraph:
            return "<p>\(node.children.map(convertToHTML).joined())</p>"
        case .heading(let level):
            return "<h\(level)>\(node.children.map(convertToHTML).joined())</h\(level)>"
        case .blockquote:
            return "<blockquote>\(node.children.map(convertToHTML).joined())</blockquote>"
        case .codeBlock:
            return "<pre><code>\(node.content.htmlEscaped())</code></pre>"
        case .list(let ordered):
            let tag = ordered ? "ol" : "ul"
            return "<\(tag)>\(node.children.map(convertToHTML).joined())</\(tag)>"
        case .listItem:
            return "<li>\(node.children.map(convertToHTML).joined())</li>"
        case .emphasis:
            return "<em>\(node.children.map(convertToHTML).joined())</em>"
        case .strong:
            return "<strong>\(node.children.map(convertToHTML).joined())</strong>"
        case .link(let destination, _):
            return "<a href=\"\(destination)\">\(node.children.map(convertToHTML).joined())</a>"
        case .text:
            return node.content.htmlEscaped()
        default:
            return node.children.map(convertToHTML).joined()
        }
    }
}

// MARK: - PDF Exporter (Placeholder)

public final class PDFExporter: Exporter {
    public let fileExtension = "pdf"
    public let mimeType = "application/pdf"

    public init() {}

    public func export(document: TymarkDocument, theme: Theme) -> Data? {
        // PDF export requires more complex implementation
        // This is a placeholder
        return nil
    }
}

// MARK: - DOCX Exporter (Placeholder)

public final class DOCXExporter: Exporter {
    public let fileExtension = "docx"
    public let mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

    public init() {}

    public func export(document: TymarkDocument, theme: Theme) -> Data? {
        // DOCX export requires more complex implementation
        // This is a placeholder
        return nil
    }
}

// MARK: - Export Manager

public final class ExportManager {
    private var exporters: [String: Exporter] = [:]

    public init() {
        register(HTMLExporter())
        register(PDFExporter())
        register(DOCXExporter())
    }

    public func register(_ exporter: Exporter) {
        exporters[exporter.fileExtension] = exporter
    }

    public func export(document: TymarkDocument, format: String, theme: Theme) -> Data? {
        return exporters[format]?.export(document: document, theme: theme)
    }

    public func availableFormats() -> [String] {
        return Array(exporters.keys)
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
