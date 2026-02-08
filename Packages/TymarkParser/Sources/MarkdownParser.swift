import Foundation
import Markdown

// MARK: - Parser Configuration

public struct ParserConfiguration {
    public var enableGitHubFlavoredMarkdown: Bool
    public var enableStrikethrough: Bool
    public var enableTables: Bool
    public var enableTaskLists: Bool

    public static let `default` = ParserConfiguration(
        enableGitHubFlavoredMarkdown: true,
        enableStrikethrough: true,
        enableTables: true,
        enableTaskLists: true
    )

    public init(
        enableGitHubFlavoredMarkdown: Bool = true,
        enableStrikethrough: Bool = true,
        enableTables: Bool = true,
        enableTaskLists: Bool = true
    ) {
        self.enableGitHubFlavoredMarkdown = enableGitHubFlavoredMarkdown
        self.enableStrikethrough = enableStrikethrough
        self.enableTables = enableTables
        self.enableTaskLists = enableTaskLists
    }
}

// MARK: - Markdown Parser

public final class MarkdownParser: @unchecked Sendable {
    private let configuration: ParserConfiguration

    public init(configuration: ParserConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public API

    public func parse(_ source: String) -> TymarkDocument {
        let markdownDocument = Document(parsing: source)
        let root = convertNode(markdownDocument, in: source, baseLocation: 0)
        return TymarkDocument(root: root, source: source)
    }

    public func parseIncremental(
        previousDocument: TymarkDocument,
        editRange: NSRange,
        newSource: String
    ) -> TymarkDocument {
        // For small edits, try to do minimal work
        let editSize = editRange.length
        let documentSize = newSource.count

        // If edit is small relative to document and not structural, optimize
        if editSize < 1000 && documentSize > 5000 {
            return parseIncrementalOptimized(
                previousDocument: previousDocument,
                editRange: editRange,
                newSource: newSource
            )
        }

        // Fall back to full re-parse
        return parse(newSource)
    }

    // MARK: - Private Methods

    private func parseIncrementalOptimized(
        previousDocument: TymarkDocument,
        editRange: NSRange,
        newSource: String
    ) -> TymarkDocument {
        // Find the block-level node containing the edit
        let containingBlock = findContainingBlock(previousDocument.root, at: editRange.location)

        // If we found a block, try to re-parse just that block
        if let block = containingBlock {
            let blockRange = block.range
            let blockSource = extractSource(for: blockRange, from: newSource)

            // Parse just this block
            let parsedBlock = parseBlock(blockSource, at: blockRange.location)

            // Merge the parsed block back into the tree
            let newRoot = mergeBlock(
                oldRoot: previousDocument.root,
                oldBlock: block,
                newBlock: parsedBlock,
                editDelta: newSource.count - previousDocument.source.count
            )

            return TymarkDocument(root: newRoot, source: newSource)
        }

        // Fall back to full parse
        return parse(newSource)
    }

    private func findContainingBlock(_ node: TymarkNode, at location: Int) -> TymarkNode? {
        if !NSLocationInRange(location, node.range) {
            return nil
        }

        // Check children first (depth-first)
        for child in node.children where child.isBlock {
            if let found = findContainingBlock(child, at: location) {
                return found
            }
        }

        // If no child contains it, this node does
        return node.isBlock ? node : nil
    }

    private func extractSource(for range: NSRange, from source: String) -> String {
        guard range.location >= 0 && range.length > 0 else { return "" }
        guard let stringRange = Range(range, in: source) else { return "" }
        return String(source[stringRange])
    }

    private func parseBlock(_ source: String, at location: Int) -> TymarkNode {
        let document = Document(parsing: source)
        // Get the first child using the children collection
        var firstChild: Markup? = nil
        for child in document.children {
            firstChild = child
            break
        }
        if let child = firstChild {
            return convertNode(child, in: source, baseLocation: location)
        }
        return TymarkNode(type: .paragraph, range: NSRange(location: location, length: source.count))
    }

    private func mergeBlock(
        oldRoot: TymarkNode,
        oldBlock: TymarkNode,
        newBlock: TymarkNode,
        editDelta: Int
    ) -> TymarkNode {
        // Adjust ranges after the edit
        return adjustRanges(in: oldRoot, replacing: oldBlock, with: newBlock, editDelta: editDelta)
    }

    private func adjustRanges(
        in node: TymarkNode,
        replacing oldBlock: TymarkNode,
        with newBlock: TymarkNode,
        editDelta: Int
    ) -> TymarkNode {
        let oldEnd = NSMaxRange(oldBlock.range)

        // Calculate new range
        let adjustedRange: NSRange
        if NSEqualRanges(node.range, oldBlock.range) {
            // This is the replaced block
            adjustedRange = newBlock.range
        } else if node.range.location >= oldEnd {
            // This node is after the edit, shift it
            let newLocation = node.range.location + editDelta
            adjustedRange = NSRange(location: newLocation, length: node.range.length)
        } else if NSMaxRange(node.range) <= oldBlock.range.location {
            // This node is before the edit, keep it
            adjustedRange = node.range
        } else if NSLocationInRange(node.range.location, oldBlock.range) ||
                  NSLocationInRange(NSMaxRange(node.range), oldBlock.range) {
            // This node overlaps the edited block - use the new block's range
            adjustedRange = newBlock.range
        } else {
            adjustedRange = node.range
        }

        // Recursively adjust children
        let adjustedChildren = node.children.map { child in
            adjustRanges(in: child, replacing: oldBlock, with: newBlock, editDelta: editDelta)
        }

        return TymarkNode(
            id: node.id,
            type: node.type,
            content: node.content,
            range: adjustedRange,
            children: adjustedChildren,
            metadata: node.metadata
        )
    }

    // MARK: - Node Conversion

    private func convertNode(_ node: Markup, in source: String, baseLocation: Int) -> TymarkNode {
        let range = node.range(in: source, baseLocation: baseLocation)

        switch node {
        case let document as Document:
            return convertDocument(document, in: source, range: range)
        case let paragraph as Paragraph:
            return convertParagraph(paragraph, in: source, range: range)
        case let heading as Heading:
            return convertHeading(heading, in: source, range: range)
        case let blockQuote as BlockQuote:
            return convertBlockQuote(blockQuote, in: source, range: range)
        case let list as UnorderedList:
            return convertList(list, ordered: false, in: source, range: range)
        case let list as OrderedList:
            return convertList(list, ordered: true, in: source, range: range)
        case let item as ListItem:
            return convertListItem(item, in: source, range: range)
        case let codeBlock as CodeBlock:
            return convertCodeBlock(codeBlock, in: source, range: range)
        case let inlineCode as InlineCode:
            return convertInlineCode(inlineCode, in: source, range: range)
        case let emphasis as Emphasis:
            return convertEmphasis(emphasis, in: source, range: range)
        case let strong as Strong:
            return convertStrong(strong, in: source, range: range)
        case let link as Link:
            return convertLink(link, in: source, range: range)
        case let image as Image:
            return convertImage(image, in: source, range: range)
        case let text as Markdown.Text:
            return convertText(text, in: source, range: range)
        case let softBreak as SoftBreak:
            return convertSoftBreak(softBreak, in: source, range: range)
        case let lineBreak as LineBreak:
            return convertLineBreak(lineBreak, in: source, range: range)
        case let thematicBreak as ThematicBreak:
            return convertThematicBreak(thematicBreak, in: source, range: range)
        case let table as Markdown.Table:
            return convertTable(table, in: source, range: range)
        case let tableRow as Markdown.Table.Row:
            return convertTableRow(tableRow, in: source, range: range)
        case let tableCell as Markdown.Table.Cell:
            return convertTableCell(tableCell, in: source, range: range)
        case let strikethrough as Strikethrough:
            return convertStrikethrough(strikethrough, in: source, range: range)
        case let html as InlineHTML:
            return convertInlineHTML(html, in: source, range: range)
        case let html as HTMLBlock:
            return convertHTMLBlock(html, in: source, range: range)
        default:
            return TymarkNode(
                type: .custom(name: String(describing: type(of: node))),
                content: "",
                range: range,
                children: node.children.map { convertNode($0, in: source, baseLocation: baseLocation) }
            )
        }
    }

    private func convertDocument(_ document: Document, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .document,
            content: "",
            range: range,
            children: document.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertParagraph(_ paragraph: Paragraph, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .paragraph,
            content: extractContent(for: range, from: source),
            range: range,
            children: paragraph.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertHeading(_ heading: Heading, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .heading(level: heading.level),
            content: extractContent(for: range, from: source),
            range: range,
            children: heading.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertBlockQuote(_ blockQuote: BlockQuote, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .blockquote,
            content: extractContent(for: range, from: source),
            range: range,
            children: blockQuote.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertList(_ list: ListItemContainer, ordered: Bool, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .list(ordered: ordered),
            content: extractContent(for: range, from: source),
            range: range,
            children: list.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertListItem(_ item: ListItem, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .listItem,
            content: extractContent(for: range, from: source),
            range: range,
            children: item.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertCodeBlock(_ codeBlock: CodeBlock, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .codeBlock(language: codeBlock.language),
            content: codeBlock.code,
            range: range,
            children: []
        )
    }

    private func convertInlineCode(_ inlineCode: InlineCode, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .inlineCode,
            content: inlineCode.code,
            range: range,
            children: []
        )
    }

    private func convertEmphasis(_ emphasis: Emphasis, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .emphasis,
            content: extractContent(for: range, from: source),
            range: range,
            children: emphasis.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertStrong(_ strong: Strong, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .strong,
            content: extractContent(for: range, from: source),
            range: range,
            children: strong.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertLink(_ link: Link, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .link(destination: link.destination ?? "", title: link.title),
            content: extractContent(for: range, from: source),
            range: range,
            children: link.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertImage(_ image: Image, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .image(source: image.source ?? "", alt: image.plainText),
            content: "",
            range: range,
            children: []
        )
    }

    private func convertText(_ text: Markdown.Text, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .text,
            content: text.string,
            range: range,
            children: []
        )
    }

    private func convertSoftBreak(_ softBreak: SoftBreak, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .softBreak,
            content: " ",
            range: range,
            children: []
        )
    }

    private func convertLineBreak(_ lineBreak: LineBreak, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .lineBreak,
            content: "\n",
            range: range,
            children: []
        )
    }

    private func convertThematicBreak(_ thematicBreak: ThematicBreak, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .thematicBreak,
            content: extractContent(for: range, from: source),
            range: range,
            children: []
        )
    }

    private func convertTable(_ table: Markdown.Table, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .table,
            content: extractContent(for: range, from: source),
            range: range,
            children: table.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertTableRow(_ row: Markdown.Table.Row, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .tableRow,
            content: extractContent(for: range, from: source),
            range: range,
            children: row.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertTableCell(_ cell: Markdown.Table.Cell, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .tableCell,
            content: extractContent(for: range, from: source),
            range: range,
            children: cell.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertStrikethrough(_ strikethrough: Strikethrough, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .strikethrough,
            content: extractContent(for: range, from: source),
            range: range,
            children: strikethrough.children.map { convertNode($0, in: source, baseLocation: range.location) }
        )
    }

    private func convertInlineHTML(_ html: InlineHTML, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .html,
            content: html.rawHTML,
            range: range,
            children: []
        )
    }

    private func convertHTMLBlock(_ html: HTMLBlock, in source: String, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .html,
            content: html.rawHTML,
            range: range,
            children: []
        )
    }

    // MARK: - Helpers

    private func extractContent(for range: NSRange, from source: String) -> String {
        guard range.location >= 0 && range.length > 0 else { return "" }
        guard let stringRange = Range(range, in: source) else { return "" }
        return String(source[stringRange])
    }
}

// MARK: - Markup Extensions

extension Markup {
    func range(in source: String, baseLocation: Int) -> NSRange {
        // Use swift-markdown's built-in SourceRange when available
        if let sourceRange = self.range {
            let startLine = sourceRange.lowerBound.line - 1 // 0-indexed
            let startCol = sourceRange.lowerBound.column - 1
            let endLine = sourceRange.upperBound.line - 1
            let endCol = sourceRange.upperBound.column - 1

            let lines = source.components(separatedBy: "\n")

            // Calculate UTF-16 offset for start
            var startOffset = 0
            for i in 0..<min(startLine, lines.count) {
                startOffset += (lines[i] as NSString).length + 1 // +1 for \n
            }
            if startLine < lines.count {
                startOffset += min(startCol, (lines[startLine] as NSString).length)
            }

            // Calculate UTF-16 offset for end
            var endOffset = 0
            for i in 0..<min(endLine, lines.count) {
                endOffset += (lines[i] as NSString).length + 1
            }
            if endLine < lines.count {
                endOffset += min(endCol, (lines[endLine] as NSString).length)
            }

            let location = startOffset
            let length = max(0, endOffset - startOffset)
            return NSRange(location: location, length: length)
        }

        // Fallback: compute from children ranges
        var firstRange: NSRange?
        var lastRange: NSRange?
        for child in self.children {
            let childRange = child.range(in: source, baseLocation: baseLocation)
            if firstRange == nil {
                firstRange = childRange
            }
            lastRange = childRange
        }

        if let first = firstRange, let last = lastRange {
            let location = first.location
            let length = NSMaxRange(last) - location
            return NSRange(location: location, length: max(0, length))
        }

        // Leaf node without source range — return zero-length at base
        return NSRange(location: baseLocation, length: 0)
    }
}
