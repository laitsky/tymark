import Foundation
import AppKit
import TymarkParser
import TymarkTheme

// MARK: - PDF Exporter

/// Generates styled PDF documents from the markdown AST using Core Graphics.
/// Respects theme colors and fonts, handles all markdown elements including
/// headings, code blocks, blockquotes, tables, images, and inline formatting.
public final class PDFExporter: Exporter {
    public let fileExtension = "pdf"
    public let mimeType = "application/pdf"

    // MARK: - Page Layout

    private struct PageLayout {
        let pageSize: CGSize
        let margins: NSEdgeInsets
        var contentRect: CGRect {
            CGRect(
                x: margins.left,
                y: margins.bottom,
                width: pageSize.width - margins.left - margins.right,
                height: pageSize.height - margins.top - margins.bottom
            )
        }
    }

    private let layout: PageLayout

    // MARK: - Initialization

    public init(
        pageSize: CGSize = CGSize(width: 612, height: 792), // US Letter
        margins: NSEdgeInsets = NSEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
    ) {
        self.layout = PageLayout(pageSize: pageSize, margins: margins)
    }

    // MARK: - Exporter Protocol

    public func export(document: TymarkParser.TymarkDocument, theme: Theme) -> Data? {
        let attributedString = buildAttributedString(from: document.root, theme: theme)
        return renderPDF(attributedString: attributedString, theme: theme)
    }

    // MARK: - PDF Rendering

    private func renderPDF(attributedString: NSAttributedString, theme: Theme) -> Data? {
        let pdfData = NSMutableData()

        var mediaBox = CGRect(origin: .zero, size: layout.pageSize)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        let contentRect = layout.contentRect
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let textLength = attributedString.length
        var currentIndex = 0

        while currentIndex < textLength {
            // Begin a new page
            pdfContext.beginPDFPage(nil)

            // Draw background
            pdfContext.setFillColor(theme.colors.background.nsColor.cgColor)
            pdfContext.fill(CGRect(origin: .zero, size: layout.pageSize))

            // Create frame path
            let framePath = CGPath(rect: contentRect, transform: nil)

            // Create frame for current text range
            let frameRange = CFRange(location: currentIndex, length: 0)
            let frame = CTFramesetterCreateFrame(framesetter, frameRange, framePath, nil)

            // Draw the text frame
            pdfContext.saveGState()
            // Core Text uses a flipped coordinate system from PDF
            pdfContext.textMatrix = .identity
            CTFrameDraw(frame, pdfContext)
            pdfContext.restoreGState()

            // Determine how much text was laid out
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            let drawnLength = visibleRange.length

            if drawnLength == 0 {
                // Prevent infinite loop if nothing can be drawn
                break
            }

            currentIndex += drawnLength

            pdfContext.endPDFPage()
        }

        pdfContext.closePDF()

        return pdfData as Data
    }

    // MARK: - Attributed String Builder

    private func buildAttributedString(from node: TymarkNode, theme: Theme) -> NSAttributedString {
        let result = NSMutableAttributedString()
        appendNode(node, to: result, theme: theme, depth: 0)
        return result
    }

    private func appendNode(
        _ node: TymarkNode,
        to result: NSMutableAttributedString,
        theme: Theme,
        depth: Int
    ) {
        switch node.type {
        case .document:
            for child in node.children {
                appendNode(child, to: result, theme: theme, depth: depth)
            }

        case .paragraph:
            let para = NSMutableAttributedString()
            for child in node.children {
                appendInlineNode(child, to: para, theme: theme)
            }
            applyParagraphStyle(to: para, theme: theme, spacing: theme.spacing.paragraphSpacing)
            result.append(para)
            result.append(NSAttributedString(string: "\n"))

        case .heading(let level):
            let heading = NSMutableAttributedString()
            for child in node.children {
                appendInlineNode(child, to: heading, theme: theme)
            }
            applyHeadingStyle(to: heading, level: level, theme: theme)
            result.append(heading)
            result.append(NSAttributedString(string: "\n\n"))

        case .blockquote:
            let quote = NSMutableAttributedString()
            for child in node.children {
                appendNode(child, to: quote, theme: theme, depth: depth + 1)
            }
            applyBlockquoteStyle(to: quote, theme: theme)
            result.append(quote)

        case .codeBlock(let language):
            let code = NSMutableAttributedString(string: node.content)
            applyCodeBlockStyle(to: code, language: language, theme: theme)
            result.append(code)
            result.append(NSAttributedString(string: "\n\n"))

        case .list:
            for (index, child) in node.children.enumerated() {
                if case .list(let ordered) = node.type {
                    appendListItem(child, to: result, theme: theme, ordered: ordered, index: index + 1, depth: depth)
                } else {
                    appendListItem(child, to: result, theme: theme, ordered: false, index: index + 1, depth: depth)
                }
            }
            result.append(NSAttributedString(string: "\n"))

        case .listItem:
            for child in node.children {
                appendNode(child, to: result, theme: theme, depth: depth)
            }

        case .thematicBreak:
            let hr = NSMutableAttributedString(string: "\n\n")
            result.append(hr)

        case .table:
            for child in node.children {
                appendNode(child, to: result, theme: theme, depth: depth)
            }
            result.append(NSAttributedString(string: "\n"))

        case .tableRow:
            let row = NSMutableAttributedString()
            for (index, cell) in node.children.enumerated() {
                if index > 0 {
                    row.append(NSAttributedString(string: "  |  ", attributes: bodyAttributes(theme: theme)))
                }
                for child in cell.children {
                    appendInlineNode(child, to: row, theme: theme)
                }
            }
            row.append(NSAttributedString(string: "\n"))
            result.append(row)

        default:
            for child in node.children {
                appendNode(child, to: result, theme: theme, depth: depth)
            }
        }
    }

    private func appendListItem(
        _ node: TymarkNode,
        to result: NSMutableAttributedString,
        theme: Theme,
        ordered: Bool,
        index: Int,
        depth: Int
    ) {
        let bullet = ordered ? "\(index). " : "\u{2022} "
        let indent = String(repeating: "    ", count: depth)
        let prefix = NSAttributedString(string: indent + bullet, attributes: [
            .font: theme.fonts.body.nsFont,
            .foregroundColor: theme.colors.listMarker.nsColor
        ])

        let item = NSMutableAttributedString()
        item.append(prefix)

        for child in node.children {
            if case .paragraph = child.type {
                // Inline the paragraph content for list items
                for inline in child.children {
                    appendInlineNode(inline, to: item, theme: theme)
                }
            } else {
                appendNode(child, to: item, theme: theme, depth: depth + 1)
            }
        }

        item.append(NSAttributedString(string: "\n"))
        result.append(item)
    }

    private func appendInlineNode(
        _ node: TymarkNode,
        to result: NSMutableAttributedString,
        theme: Theme
    ) {
        switch node.type {
        case .text:
            result.append(NSAttributedString(string: node.content, attributes: bodyAttributes(theme: theme)))

        case .emphasis:
            let emphAttrs = bodyAttributes(theme: theme).merging([
                .font: NSFontManager.shared.convert(theme.fonts.body.nsFont, toHaveTrait: .italicFontMask)
            ]) { _, new in new }
            for child in node.children {
                if case .text = child.type {
                    result.append(NSAttributedString(string: child.content, attributes: emphAttrs))
                } else {
                    appendInlineNode(child, to: result, theme: theme)
                }
            }

        case .strong:
            let strongAttrs = bodyAttributes(theme: theme).merging([
                .font: NSFontManager.shared.convert(theme.fonts.body.nsFont, toHaveTrait: .boldFontMask)
            ]) { _, new in new }
            for child in node.children {
                if case .text = child.type {
                    result.append(NSAttributedString(string: child.content, attributes: strongAttrs))
                } else {
                    appendInlineNode(child, to: result, theme: theme)
                }
            }

        case .inlineCode:
            let codeAttrs: [NSAttributedString.Key: Any] = [
                .font: theme.fonts.code.nsFont,
                .foregroundColor: theme.colors.codeText.nsColor,
                .backgroundColor: theme.colors.codeBackground.nsColor
            ]
            result.append(NSAttributedString(string: node.content, attributes: codeAttrs))

        case .link(let destination, _):
            let linkAttrs = bodyAttributes(theme: theme).merging([
                .foregroundColor: theme.colors.link.nsColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: URL(string: destination) as Any
            ]) { _, new in new }
            for child in node.children {
                if case .text = child.type {
                    result.append(NSAttributedString(string: child.content, attributes: linkAttrs))
                } else {
                    appendInlineNode(child, to: result, theme: theme)
                }
            }

        case .wikilink(let target, _):
            let destination = URL(fileURLWithPath: target + ".md")
            let linkAttrs = bodyAttributes(theme: theme).merging([
                .foregroundColor: theme.colors.link.nsColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: destination
            ]) { _, new in new }
            result.append(NSAttributedString(string: target, attributes: linkAttrs))

        case .image(_, let alt):
            // For PDF, represent images as alt text in brackets
            let altText = alt ?? "image"
            result.append(NSAttributedString(string: "[\(altText)]", attributes: bodyAttributes(theme: theme)))

        case .strikethrough:
            let strikeAttrs = bodyAttributes(theme: theme).merging([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]) { _, new in new }
            for child in node.children {
                if case .text = child.type {
                    result.append(NSAttributedString(string: child.content, attributes: strikeAttrs))
                } else {
                    appendInlineNode(child, to: result, theme: theme)
                }
            }

        case .softBreak:
            result.append(NSAttributedString(string: " ", attributes: bodyAttributes(theme: theme)))

        case .lineBreak:
            result.append(NSAttributedString(string: "\n", attributes: bodyAttributes(theme: theme)))

        default:
            for child in node.children {
                appendInlineNode(child, to: result, theme: theme)
            }
        }
    }

    // MARK: - Style Helpers

    private func bodyAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
        [
            .font: theme.fonts.body.nsFont,
            .foregroundColor: theme.colors.text.nsColor
        ]
    }

    private func applyParagraphStyle(to string: NSMutableAttributedString, theme: Theme, spacing: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = spacing
        style.lineHeightMultiple = theme.spacing.lineHeight

        let range = NSRange(location: 0, length: string.length)
        string.addAttributes([
            .font: theme.fonts.body.nsFont,
            .foregroundColor: theme.colors.text.nsColor,
            .paragraphStyle: style
        ], range: range)
    }

    private func applyHeadingStyle(to string: NSMutableAttributedString, level: Int, theme: Theme) {
        let sizeMultipliers: [Int: CGFloat] = [1: 2.0, 2: 1.5, 3: 1.25, 4: 1.1, 5: 1.0, 6: 0.9]
        let multiplier = sizeMultipliers[level] ?? 1.0
        let fontSize = theme.fonts.body.size * multiplier

        let headingFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)

        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = theme.spacing.headingSpacingTop
        style.paragraphSpacing = theme.spacing.headingSpacingBottom

        let range = NSRange(location: 0, length: string.length)
        string.addAttributes([
            .font: headingFont,
            .foregroundColor: theme.colors.heading.nsColor,
            .paragraphStyle: style
        ], range: range)
    }

    private func applyBlockquoteStyle(to string: NSMutableAttributedString, theme: Theme) {
        let style = NSMutableParagraphStyle()
        style.headIndent = theme.spacing.blockquoteIndentation
        style.firstLineHeadIndent = theme.spacing.blockquoteIndentation
        style.paragraphSpacing = theme.spacing.paragraphSpacing / 2

        let range = NSRange(location: 0, length: string.length)
        string.addAttributes([
            .foregroundColor: theme.colors.quoteText.nsColor,
            .paragraphStyle: style
        ], range: range)
    }

    private func applyCodeBlockStyle(to string: NSMutableAttributedString, language: String?, theme: Theme) {
        let style = NSMutableParagraphStyle()
        style.headIndent = theme.spacing.codeBlockPadding
        style.firstLineHeadIndent = theme.spacing.codeBlockPadding
        style.tailIndent = -theme.spacing.codeBlockPadding

        let range = NSRange(location: 0, length: string.length)
        string.addAttributes([
            .font: theme.fonts.code.nsFont,
            .foregroundColor: theme.colors.codeText.nsColor,
            .backgroundColor: theme.colors.codeBackground.nsColor,
            .paragraphStyle: style
        ], range: range)
    }
}
