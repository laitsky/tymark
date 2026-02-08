import Foundation
import TymarkParser
import TymarkTheme
import AppKit

// MARK: - Export Protocol

public protocol Exporter {
    func export(document: TymarkParser.TymarkDocument, theme: Theme) -> Data?
    var fileExtension: String { get }
    var mimeType: String { get }
}

// MARK: - HTML Exporter

public final class HTMLExporter: Exporter {
    public let fileExtension = "html"
    public let mimeType = "text/html"

    public init() {}

    public func export(document: TymarkParser.TymarkDocument, theme: Theme) -> Data? {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Tymark Export</title>
        <style>
        \(generateCSS(theme: theme))
        </style>
        </head>
        <body>
        <article class="markdown-body">
        \(convertToHTML(document.root))
        </article>
        </body>
        </html>
        """
        return html.data(using: .utf8)
    }

    private func generateCSS(theme: Theme) -> String {
        """
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: \(Int(theme.fonts.body.size))px;
            line-height: \(theme.spacing.lineHeight);
            max-width: 800px;
            margin: 0 auto;
            padding: 24px;
            color: \(theme.colors.text.hexString);
            background: \(theme.colors.background.hexString);
            -webkit-font-smoothing: antialiased;
        }
        .markdown-body { max-width: 100%; }
        h1, h2, h3, h4, h5, h6 {
            color: \(theme.colors.heading.hexString);
            margin-top: 1.5em;
            margin-bottom: 0.5em;
            font-weight: 600;
            line-height: 1.3;
        }
        h1 { font-size: 2em; border-bottom: 1px solid \(theme.colors.quoteBorder.hexString); padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid \(theme.colors.quoteBorder.hexString); padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1.1em; }
        h5 { font-size: 1em; }
        h6 { font-size: 0.9em; opacity: 0.8; }
        p { margin-bottom: 1em; }
        a { color: \(theme.colors.link.hexString); text-decoration: none; }
        a:hover { text-decoration: underline; }
        code {
            font-family: '\(theme.fonts.code.family)', monospace;
            font-size: 0.9em;
            background: \(theme.colors.codeBackground.hexString);
            color: \(theme.colors.codeText.hexString);
            padding: 2px 6px;
            border-radius: 3px;
        }
        pre {
            background: \(theme.colors.codeBackground.hexString);
            padding: 16px;
            border-radius: 6px;
            overflow-x: auto;
            margin-bottom: 1em;
        }
        pre code { background: none; padding: 0; font-size: 0.85em; line-height: 1.5; }
        blockquote {
            border-left: 4px solid \(theme.colors.quoteBorder.hexString);
            margin: 0 0 1em 0;
            padding: 0.5em 0 0.5em 16px;
            color: \(theme.colors.quoteText.hexString);
        }
        blockquote p { margin-bottom: 0.5em; }
        ul, ol { margin-bottom: 1em; padding-left: 2em; }
        li { margin-bottom: 0.25em; }
        hr { border: none; border-top: 2px solid \(theme.colors.quoteBorder.hexString); margin: 2em 0; }
        table { border-collapse: collapse; margin-bottom: 1em; width: 100%; }
        th, td { border: 1px solid \(theme.colors.quoteBorder.hexString); padding: 8px 12px; text-align: left; }
        th { font-weight: 600; background: \(theme.colors.codeBackground.hexString); }
        img { max-width: 100%; height: auto; border-radius: 4px; }
        del { text-decoration: line-through; opacity: 0.7; }
        """
    }

    private func convertToHTML(_ node: TymarkNode) -> String {
        switch node.type {
        case .document:
            return node.children.map(convertToHTML).joined()

        case .paragraph:
            return "<p>\(node.children.map(convertToHTML).joined())</p>\n"

        case .heading(let level):
            return "<h\(level)>\(node.children.map(convertToHTML).joined())</h\(level)>\n"

        case .blockquote:
            return "<blockquote>\(node.children.map(convertToHTML).joined())</blockquote>\n"

        case .codeBlock(let language):
            let langClass = language.map { " class=\"language-\($0)\"" } ?? ""
            return "<pre><code\(langClass)>\(escapeHTML(node.content))</code></pre>\n"

        case .inlineCode:
            return "<code>\(escapeHTML(node.content))</code>"

        case .list(let ordered):
            let tag = ordered ? "ol" : "ul"
            return "<\(tag)>\n\(node.children.map(convertToHTML).joined())</\(tag)>\n"

        case .listItem:
            return "<li>\(node.children.map(convertToHTML).joined())</li>\n"

        case .emphasis:
            return "<em>\(node.children.map(convertToHTML).joined())</em>"

        case .strong:
            return "<strong>\(node.children.map(convertToHTML).joined())</strong>"

        case .strikethrough:
            return "<del>\(node.children.map(convertToHTML).joined())</del>"

        case .link(let destination, let title):
            let titleAttr = title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
            return "<a href=\"\(escapeHTML(destination))\"\(titleAttr)>\(node.children.map(convertToHTML).joined())</a>"

        case .image(let source, let alt):
            let altAttr = alt.map { " alt=\"\(escapeHTML($0))\"" } ?? ""
            return "<img src=\"\(escapeHTML(source))\"\(altAttr)>\n"

        case .text:
            return escapeHTML(node.content)

        case .softBreak:
            return "\n"

        case .lineBreak:
            return "<br>\n"

        case .thematicBreak:
            return "<hr>\n"

        case .table:
            return "<table>\n\(convertTableContent(node))</table>\n"

        case .tableRow:
            return "<tr>\(node.children.map(convertToHTML).joined())</tr>\n"

        case .tableCell:
            return "<td>\(node.children.map(convertToHTML).joined())</td>"

        case .html:
            return node.content

        default:
            return node.children.map(convertToHTML).joined()
        }
    }

    private func convertTableContent(_ table: TymarkNode) -> String {
        var html = ""
        for (index, row) in table.children.enumerated() {
            guard case .tableRow = row.type else { continue }

            if index == 0 {
                // Header row
                html += "<thead>\n<tr>"
                for cell in row.children {
                    html += "<th>\(cell.children.map(convertToHTML).joined())</th>"
                }
                html += "</tr>\n</thead>\n<tbody>\n"
            } else {
                html += "<tr>"
                for cell in row.children {
                    html += "<td>\(cell.children.map(convertToHTML).joined())</td>"
                }
                html += "</tr>\n"
            }
        }
        if !table.children.isEmpty {
            html += "</tbody>\n"
        }
        return html
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - Rich Text (RTF) Exporter

public final class RichTextExporter: Exporter {
    public let fileExtension = "rtf"
    public let mimeType = "application/rtf"

    public init() {}

    public func export(document: TymarkParser.TymarkDocument, theme: Theme) -> Data? {
        let attributedString = buildAttributedString(from: document.root, theme: theme)

        return attributedString.rtf(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [
                .documentType: NSAttributedString.DocumentType.rtf,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
        )
    }

    /// Generate an NSAttributedString suitable for pasteboard copy.
    public func attributedString(from document: TymarkParser.TymarkDocument, theme: Theme) -> NSAttributedString {
        return buildAttributedString(from: document.root, theme: theme)
    }

    // MARK: - Attributed String Builder

    private func buildAttributedString(from node: TymarkNode, theme: Theme) -> NSAttributedString {
        let result = NSMutableAttributedString()
        appendNode(node, to: result, theme: theme)
        return result
    }

    private func appendNode(_ node: TymarkNode, to result: NSMutableAttributedString, theme: Theme) {
        switch node.type {
        case .document:
            for child in node.children {
                appendNode(child, to: result, theme: theme)
            }

        case .paragraph:
            let para = NSMutableAttributedString()
            for child in node.children {
                appendInline(child, to: para, theme: theme)
            }
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = theme.spacing.paragraphSpacing
            style.lineHeightMultiple = theme.spacing.lineHeight
            para.addAttributes([.paragraphStyle: style], range: NSRange(location: 0, length: para.length))
            result.append(para)
            result.append(NSAttributedString(string: "\n"))

        case .heading(let level):
            let heading = NSMutableAttributedString()
            for child in node.children {
                appendInline(child, to: heading, theme: theme)
            }
            let sizeMultipliers: [Int: CGFloat] = [1: 2.0, 2: 1.5, 3: 1.25, 4: 1.1, 5: 1.0, 6: 0.9]
            let fontSize = theme.fonts.body.size * (sizeMultipliers[level] ?? 1.0)
            let headingFont = NSFont.boldSystemFont(ofSize: fontSize)
            heading.addAttributes([
                .font: headingFont,
                .foregroundColor: theme.colors.heading.nsColor
            ], range: NSRange(location: 0, length: heading.length))
            result.append(heading)
            result.append(NSAttributedString(string: "\n\n"))

        case .blockquote:
            let quote = NSMutableAttributedString()
            for child in node.children {
                appendNode(child, to: quote, theme: theme)
            }
            let style = NSMutableParagraphStyle()
            style.headIndent = theme.spacing.blockquoteIndentation
            style.firstLineHeadIndent = theme.spacing.blockquoteIndentation
            quote.addAttributes([
                .foregroundColor: theme.colors.quoteText.nsColor,
                .paragraphStyle: style
            ], range: NSRange(location: 0, length: quote.length))
            result.append(quote)

        case .codeBlock:
            let code = NSAttributedString(string: node.content + "\n\n", attributes: [
                .font: theme.fonts.code.nsFont,
                .foregroundColor: theme.colors.codeText.nsColor,
                .backgroundColor: theme.colors.codeBackground.nsColor
            ])
            result.append(code)

        case .list:
            for (index, child) in node.children.enumerated() {
                let isOrdered: Bool
                if case .list(let ordered) = node.type { isOrdered = ordered } else { isOrdered = false }
                let bullet = isOrdered ? "\(index + 1). " : "\u{2022} "
                let prefix = NSAttributedString(string: bullet, attributes: bodyAttributes(theme))
                result.append(prefix)
                for grandchild in child.children {
                    appendNode(grandchild, to: result, theme: theme)
                }
            }
            result.append(NSAttributedString(string: "\n"))

        case .thematicBreak:
            result.append(NSAttributedString(string: "\n---\n\n", attributes: bodyAttributes(theme)))

        default:
            for child in node.children {
                appendNode(child, to: result, theme: theme)
            }
        }
    }

    private func appendInline(_ node: TymarkNode, to result: NSMutableAttributedString, theme: Theme) {
        switch node.type {
        case .text:
            result.append(NSAttributedString(string: node.content, attributes: bodyAttributes(theme)))

        case .emphasis:
            let font = NSFontManager.shared.convert(theme.fonts.body.nsFont, toHaveTrait: .italicFontMask)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: theme.colors.text.nsColor
            ]
            for child in node.children {
                if case .text = child.type {
                    result.append(NSAttributedString(string: child.content, attributes: attrs))
                } else {
                    appendInline(child, to: result, theme: theme)
                }
            }

        case .strong:
            let font = NSFontManager.shared.convert(theme.fonts.body.nsFont, toHaveTrait: .boldFontMask)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: theme.colors.text.nsColor
            ]
            for child in node.children {
                if case .text = child.type {
                    result.append(NSAttributedString(string: child.content, attributes: attrs))
                } else {
                    appendInline(child, to: result, theme: theme)
                }
            }

        case .inlineCode:
            let attrs: [NSAttributedString.Key: Any] = [
                .font: theme.fonts.code.nsFont,
                .foregroundColor: theme.colors.codeText.nsColor,
                .backgroundColor: theme.colors.codeBackground.nsColor
            ]
            result.append(NSAttributedString(string: node.content, attributes: attrs))

        case .link(let destination, _):
            var attrs = bodyAttributes(theme)
            attrs[.foregroundColor] = theme.colors.link.nsColor
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            if let url = URL(string: destination) {
                attrs[.link] = url
            }
            for child in node.children {
                if case .text = child.type {
                    result.append(NSAttributedString(string: child.content, attributes: attrs))
                } else {
                    appendInline(child, to: result, theme: theme)
                }
            }

        case .strikethrough:
            var attrs = bodyAttributes(theme)
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            for child in node.children {
                if case .text = child.type {
                    result.append(NSAttributedString(string: child.content, attributes: attrs))
                } else {
                    appendInline(child, to: result, theme: theme)
                }
            }

        case .softBreak:
            result.append(NSAttributedString(string: " ", attributes: bodyAttributes(theme)))

        case .lineBreak:
            result.append(NSAttributedString(string: "\n", attributes: bodyAttributes(theme)))

        default:
            for child in node.children {
                appendInline(child, to: result, theme: theme)
            }
        }
    }

    private func bodyAttributes(_ theme: Theme) -> [NSAttributedString.Key: Any] {
        [
            .font: theme.fonts.body.nsFont,
            .foregroundColor: theme.colors.text.nsColor
        ]
    }
}

// MARK: - Export Manager

public final class ExportManager {
    private var exporters: [String: Exporter] = [:]

    public init() {
        register(HTMLExporter())
        register(PDFExporter())
        register(DOCXExporter())
        register(RichTextExporter())
    }

    public func register(_ exporter: Exporter) {
        exporters[exporter.fileExtension] = exporter
    }

    public func export(document: TymarkParser.TymarkDocument, format: String, theme: Theme) -> Data? {
        return exporters[format]?.export(document: document, theme: theme)
    }

    public func exporter(for format: String) -> Exporter? {
        return exporters[format]
    }

    public func availableFormats() -> [String] {
        return Array(exporters.keys).sorted()
    }
}
