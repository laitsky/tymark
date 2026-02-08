import Foundation
import AppKit

// MARK: - Markdown Preview Provider

/// Generates styled HTML previews of markdown documents for Quick Look integration
/// and general-purpose preview rendering.
public final class MarkdownPreviewProvider: @unchecked Sendable {

    // MARK: - Types

    public struct PreviewStyle: Sendable {
        public var fontFamily: String
        public var codeFontFamily: String
        public var fontSize: CGFloat
        public var textColor: String
        public var backgroundColor: String
        public var linkColor: String
        public var codeBackgroundColor: String
        public var quoteBorderColor: String
        public var maxWidth: CGFloat

        public init(
            fontFamily: String = "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif",
            codeFontFamily: String = "'SF Mono', Menlo, monospace",
            fontSize: CGFloat = 14,
            textColor: String = "#333333",
            backgroundColor: String = "#ffffff",
            linkColor: String = "#0066cc",
            codeBackgroundColor: String = "#f4f4f4",
            quoteBorderColor: String = "#dddddd",
            maxWidth: CGFloat = 800
        ) {
            self.fontFamily = fontFamily
            self.codeFontFamily = codeFontFamily
            self.fontSize = fontSize
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.linkColor = linkColor
            self.codeBackgroundColor = codeBackgroundColor
            self.quoteBorderColor = quoteBorderColor
            self.maxWidth = maxWidth
        }

        /// A dark mode variant of the default style.
        public static let dark = PreviewStyle(
            textColor: "#e0e0e0",
            backgroundColor: "#1e1e1e",
            linkColor: "#4da6ff",
            codeBackgroundColor: "#2d2d2d",
            quoteBorderColor: "#444444"
        )
    }

    // MARK: - Properties

    private let style: PreviewStyle

    // MARK: - Initialization

    public init(style: PreviewStyle = PreviewStyle()) {
        self.style = style
    }

    // MARK: - Public API

    /// Generate a complete HTML document preview from markdown content.
    public func generateHTMLPreview(from markdown: String, title: String? = nil) -> String {
        let documentTitle = title ?? extractTitle(from: markdown) ?? "Preview"
        let bodyHTML = convertMarkdownToHTML(markdown)

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(escapeHTML(documentTitle))</title>
        <style>
        \(generateCSS())
        </style>
        </head>
        <body>
        <article class="markdown-body">
        \(bodyHTML)
        </article>
        </body>
        </html>
        """
    }

    /// Generate just the HTML body content (no wrapper) for embedding.
    public func generateHTMLBody(from markdown: String) -> String {
        return convertMarkdownToHTML(markdown)
    }

    /// Generate preview data suitable for Quick Look.
    public func generatePreviewData(from markdown: String, title: String? = nil) -> Data? {
        return generateHTMLPreview(from: markdown, title: title).data(using: .utf8)
    }

    // MARK: - CSS Generation

    private func generateCSS() -> String {
        """
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: \(style.fontFamily);
            font-size: \(Int(style.fontSize))px;
            line-height: 1.65;
            color: \(style.textColor);
            background: \(style.backgroundColor);
            padding: 24px;
            -webkit-font-smoothing: antialiased;
        }
        .markdown-body {
            max-width: \(Int(style.maxWidth))px;
            margin: 0 auto;
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 1.5em;
            margin-bottom: 0.5em;
            font-weight: 600;
            line-height: 1.3;
        }
        h1 { font-size: 2em; border-bottom: 1px solid \(style.quoteBorderColor); padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid \(style.quoteBorderColor); padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; opacity: 0.8; }
        p {
            margin-bottom: 1em;
        }
        a {
            color: \(style.linkColor);
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        code {
            font-family: \(style.codeFontFamily);
            font-size: 0.9em;
            background: \(style.codeBackgroundColor);
            padding: 2px 6px;
            border-radius: 3px;
        }
        pre {
            background: \(style.codeBackgroundColor);
            padding: 16px;
            border-radius: 6px;
            overflow-x: auto;
            margin-bottom: 1em;
        }
        pre code {
            background: none;
            padding: 0;
            font-size: 0.85em;
            line-height: 1.5;
        }
        blockquote {
            border-left: 4px solid \(style.quoteBorderColor);
            margin: 0 0 1em 0;
            padding: 0.5em 0 0.5em 16px;
            color: \(style.textColor);
            opacity: 0.8;
        }
        blockquote p {
            margin-bottom: 0.5em;
        }
        ul, ol {
            margin-bottom: 1em;
            padding-left: 2em;
        }
        li {
            margin-bottom: 0.25em;
        }
        hr {
            border: none;
            border-top: 2px solid \(style.quoteBorderColor);
            margin: 2em 0;
        }
        table {
            border-collapse: collapse;
            margin-bottom: 1em;
            width: 100%;
        }
        th, td {
            border: 1px solid \(style.quoteBorderColor);
            padding: 8px 12px;
            text-align: left;
        }
        th {
            font-weight: 600;
            background: \(style.codeBackgroundColor);
        }
        img {
            max-width: 100%;
            height: auto;
            border-radius: 4px;
        }
        del {
            text-decoration: line-through;
            opacity: 0.7;
        }
        """
    }

    // MARK: - Markdown to HTML Conversion

    private func convertMarkdownToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var html = ""
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeLanguage = ""
        var inBlockquote = false
        var inList = false
        var listType = ""
        var inTable = false

        for (index, line) in lines.enumerated() {
            // Code block handling
            if line.hasPrefix("```") {
                if inCodeBlock {
                    html += "<pre><code class=\"language-\(escapeHTML(codeLanguage))\">\(escapeHTML(codeBlockContent))</code></pre>\n"
                    codeBlockContent = ""
                    codeLanguage = ""
                    inCodeBlock = false
                } else {
                    closeOpenBlocks(&html, &inBlockquote, &inList, &listType, &inTable)
                    codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                if !codeBlockContent.isEmpty { codeBlockContent += "\n" }
                codeBlockContent += line
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty {
                closeOpenBlocks(&html, &inBlockquote, &inList, &listType, &inTable)
                continue
            }

            // Thematic break
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                closeOpenBlocks(&html, &inBlockquote, &inList, &listType, &inTable)
                html += "<hr>\n"
                continue
            }

            // Headings
            if let heading = parseHeading(trimmed) {
                closeOpenBlocks(&html, &inBlockquote, &inList, &listType, &inTable)
                html += heading + "\n"
                continue
            }

            // Blockquotes
            if trimmed.hasPrefix("> ") || trimmed == ">" {
                if !inBlockquote {
                    closeTable(&html, &inTable)
                    closeList(&html, &inList, &listType)
                    html += "<blockquote>\n"
                    inBlockquote = true
                }
                let content = trimmed.hasPrefix("> ") ? String(trimmed.dropFirst(2)) : ""
                html += "<p>\(processInline(content))</p>\n"
                continue
            }

            // Unordered lists
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                if !inList || listType != "ul" {
                    closeOpenBlocks(&html, &inBlockquote, &inList, &listType, &inTable)
                    html += "<ul>\n"
                    inList = true
                    listType = "ul"
                }
                html += "<li>\(processInline(String(trimmed.dropFirst(2))))</li>\n"
                continue
            }

            // Ordered lists
            if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                if !inList || listType != "ol" {
                    closeOpenBlocks(&html, &inBlockquote, &inList, &listType, &inTable)
                    html += "<ol>\n"
                    inList = true
                    listType = "ol"
                }
                let content = String(trimmed[match.upperBound...])
                html += "<li>\(processInline(content))</li>\n"
                continue
            }

            // Table detection
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                // Check if next line is a separator (this is a header row)
                let nextIndex = index + 1
                if nextIndex < lines.count {
                    let nextTrimmed = lines[nextIndex].trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.contains("---") && nextTrimmed.hasPrefix("|") {
                        closeOpenBlocks(&html, &inBlockquote, &inList, &listType, &inTable)
                        html += parseTableRow(trimmed, isHeader: true)
                        inTable = true
                        continue
                    }
                }

                // Separator line — skip
                if trimmed.contains("---") {
                    continue
                }

                // Regular table row
                html += parseTableRow(trimmed, isHeader: false)
                continue
            }

            // Non-table line: close table if open, then regular paragraph
            closeOpenBlocks(&html, &inBlockquote, &inList, &listType, &inTable)
            html += "<p>\(processInline(trimmed))</p>\n"
        }

        // Close any remaining open blocks
        closeOpenBlocks(&html, &inBlockquote, &inList, &listType, &inTable)

        return html
    }

    private func closeOpenBlocks(_ html: inout String, _ inBlockquote: inout Bool, _ inList: inout Bool, _ listType: inout String, _ inTable: inout Bool) {
        if inBlockquote {
            html += "</blockquote>\n"
            inBlockquote = false
        }
        closeTable(&html, &inTable)
        closeList(&html, &inList, &listType)
    }

    private func closeTable(_ html: inout String, _ inTable: inout Bool) {
        if inTable {
            html += "</tbody>\n</table>\n"
            inTable = false
        }
    }

    private func closeList(_ html: inout String, _ inList: inout Bool, _ listType: inout String) {
        if inList {
            html += "</\(listType)>\n"
            inList = false
            listType = ""
        }
    }

    private func parseHeading(_ line: String) -> String? {
        let levels = [
            ("######", 6), ("#####", 5), ("####", 4),
            ("###", 3), ("##", 2), ("#", 1)
        ]

        for (prefix, level) in levels {
            if line.hasPrefix(prefix + " ") {
                let content = String(line.dropFirst(prefix.count + 1))
                return "<h\(level)>\(processInline(content))</h\(level)>"
            }
        }
        return nil
    }

    private func parseTableRow(_ line: String, isHeader: Bool) -> String {
        let cells = line
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .split(separator: "|")
            .map { processInline($0.trimmingCharacters(in: .whitespaces)) }

        let tag = isHeader ? "th" : "td"
        var html = "<tr>"
        for cell in cells {
            html += "<\(tag)>\(cell)</\(tag)>"
        }
        html += "</tr>\n"

        if isHeader {
            html = "<table>\n<thead>\n" + html + "</thead>\n<tbody>\n"
        }

        return html
    }

    // MARK: - Inline Processing

    private func processInline(_ text: String) -> String {
        var result = escapeHTML(text)

        // Bold
        result = result.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "__(.+?)__",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )

        // Italic
        result = result.replacingOccurrences(
            of: "\\*(.+?)\\*",
            with: "<em>$1</em>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "_(.+?)_",
            with: "<em>$1</em>",
            options: .regularExpression
        )

        // Strikethrough
        result = result.replacingOccurrences(
            of: "~~(.+?)~~",
            with: "<del>$1</del>",
            options: .regularExpression
        )

        // Inline code
        result = result.replacingOccurrences(
            of: "`([^`]+)`",
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // Links
        result = result.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )

        // Images
        result = result.replacingOccurrences(
            of: "!\\[([^\\]]*?)\\]\\(([^)]+)\\)",
            with: "<img src=\"$2\" alt=\"$1\">",
            options: .regularExpression
        )

        return result
    }

    // MARK: - Helpers

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2))
            }
        }
        return nil
    }
}
