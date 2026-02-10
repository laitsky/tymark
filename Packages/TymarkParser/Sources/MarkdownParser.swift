import Foundation
import Markdown

// MARK: - Parser Configuration

public struct ParserConfiguration: Sendable {
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
        // Phase 7: Extract front matter before parsing
        let (frontMatter, strippedSource) = FrontMatterParser.extract(from: source)
        let frontMatterOffset = frontMatter != nil ? NSMaxRange(frontMatter!.range) : 0

        let markdownDocument = Document(parsing: strippedSource)
        var root = convertNode(
            markdownDocument,
            rangeSource: strippedSource,
            fullSource: source,
            baseLocation: frontMatterOffset
        )

        // Phase 7: Post-process for additional elements
        root = postProcess(root, source: source, frontMatter: frontMatter)

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

    // MARK: - Phase 7 Post-Processing

    private func postProcess(_ root: TymarkNode, source: String, frontMatter: FrontMatter?) -> TymarkNode {
        var children = root.children

        // 1. Prepend front matter node if present
        if let fm = frontMatter {
            let fmNode = TymarkNode(
                type: .frontMatter,
                content: fm.raw,
                range: fm.range,
                metadata: fm.fields
            )
            children.insert(fmNode, at: 0)
        }

        // 2. Reclassify ```mermaid code blocks as .mermaid nodes
        children = children.map { reclassifyMermaidBlocks($0) }

        // 3. Mark callout blockquotes (> [!NOTE], > [!WARNING], etc.)
        children = children.map { annotateCalloutBlocks($0) }

        // 4. Inject wikilinks ([[page]] and ![[embed]])
        children = injectWikilinks(in: children)

        // 5. Inject math nodes ($$...$$ block and $...$ inline)
        children = injectMathNodes(in: children, source: source, frontMatter: frontMatter)

        // 6. Footnote support
        let (footnoteRefs, footnoteDefs) = FootnoteSupport.extractFootnotes(from: source)
        if !footnoteDefs.isEmpty {
            children.append(contentsOf: footnoteDefs)
        }
        // Footnote references are inline - they'll be detected during rendering
        _ = footnoteRefs // stored for reference if needed

        return TymarkNode(
            id: root.id,
            type: root.type,
            content: root.content,
            range: NSRange(location: 0, length: (source as NSString).length),
            children: children,
            metadata: root.metadata
        )
    }

    private func annotateCalloutBlocks(_ node: TymarkNode) -> TymarkNode {
        let updatedChildren = node.children.map { annotateCalloutBlocks($0) }
        var updatedMetadata = node.metadata

        if node.type == .blockquote,
           let callout = parseCalloutHeader(from: node.content) {
            updatedMetadata["calloutKind"] = callout.kind
            if !callout.title.isEmpty {
                updatedMetadata["calloutTitle"] = callout.title
            }
        }

        return TymarkNode(
            id: node.id,
            type: node.type,
            content: node.content,
            range: node.range,
            children: updatedChildren,
            metadata: updatedMetadata
        )
    }

    private func parseCalloutHeader(from blockquoteText: String) -> (kind: String, title: String)? {
        let nsText = blockquoteText as NSString
        let pattern = #"(?im)^\s*>\s*\[!([A-Za-z]+)\]\s*(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: blockquoteText, range: range) else { return nil }

        let kindRange = match.range(at: 1)
        guard kindRange.location != NSNotFound else { return nil }
        let kind = nsText.substring(with: kindRange).uppercased()

        let titleRange = match.range(at: 2)
        let title: String
        if titleRange.location != NSNotFound {
            title = nsText.substring(with: titleRange).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            title = ""
        }

        return (kind, title)
    }

    private func injectWikilinks(in children: [TymarkNode]) -> [TymarkNode] {
        var result: [TymarkNode] = []
        result.reserveCapacity(children.count)

        for child in children {
            let transformedChild: TymarkNode
            if child.children.isEmpty {
                transformedChild = child
            } else {
                transformedChild = TymarkNode(
                    id: child.id,
                    type: child.type,
                    content: child.content,
                    range: child.range,
                    children: injectWikilinks(in: child.children),
                    metadata: child.metadata
                )
            }

            if case .text = transformedChild.type {
                result.append(contentsOf: splitTextNodeForWikilinks(transformedChild))
            } else {
                result.append(transformedChild)
            }
        }

        return result
    }

    private func splitTextNodeForWikilinks(_ textNode: TymarkNode) -> [TymarkNode] {
        guard case .text = textNode.type else { return [textNode] }

        let nsText = textNode.content as NSString
        guard nsText.length > 0 else { return [textNode] }

        let pattern = #"(!)?\[\[([^\]\n]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [textNode] }
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: textNode.content, range: fullRange)
        guard !matches.isEmpty else { return [textNode] }

        var nodes: [TymarkNode] = []
        nodes.reserveCapacity(matches.count * 2 + 1)

        var cursor = 0
        for match in matches {
            let matchRange = match.range
            guard matchRange.location != NSNotFound, matchRange.length > 0 else { continue }

            if matchRange.location > cursor {
                let plainRange = NSRange(location: cursor, length: matchRange.location - cursor)
                let plainText = nsText.substring(with: plainRange)
                nodes.append(TymarkNode(
                    type: .text,
                    content: plainText,
                    range: NSRange(
                        location: textNode.range.location + plainRange.location,
                        length: plainRange.length
                    )
                ))
            }

            let targetRange = match.range(at: 2)
            guard targetRange.location != NSNotFound else { continue }
            let rawTarget = nsText.substring(with: targetRange)
            let target = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
            let isEmbedded = match.range(at: 1).location != NSNotFound
            let rawWikilink = nsText.substring(with: matchRange)

            nodes.append(TymarkNode(
                type: .wikilink(target: target, isEmbedded: isEmbedded),
                content: rawWikilink,
                range: NSRange(
                    location: textNode.range.location + matchRange.location,
                    length: matchRange.length
                )
            ))

            cursor = NSMaxRange(matchRange)
        }

        if cursor < nsText.length {
            let tailRange = NSRange(location: cursor, length: nsText.length - cursor)
            let tailText = nsText.substring(with: tailRange)
            nodes.append(TymarkNode(
                type: .text,
                content: tailText,
                range: NSRange(
                    location: textNode.range.location + tailRange.location,
                    length: tailRange.length
                )
            ))
        }

        return nodes.isEmpty ? [textNode] : nodes
    }

    private func reclassifyMermaidBlocks(_ node: TymarkNode) -> TymarkNode {
        if case .codeBlock(let language) = node.type, language?.lowercased() == "mermaid" {
            return TymarkNode(
                id: node.id,
                type: .mermaid,
                content: node.content,
                range: node.range,
                metadata: node.metadata
            )
        }

        if !node.children.isEmpty {
            let newChildren = node.children.map { reclassifyMermaidBlocks($0) }
            return TymarkNode(
                id: node.id,
                type: node.type,
                content: node.content,
                range: node.range,
                children: newChildren,
                metadata: node.metadata
            )
        }

        return node
    }

    private func injectMathNodes(in children: [TymarkNode], source: String, frontMatter: FrontMatter? = nil) -> [TymarkNode] {
        // Detect $$...$$ block math in the source
        let nsSource = source as NSString
        let fmEnd = frontMatter.map { NSMaxRange($0.range) } ?? 0

        // Collect ranges of existing code blocks to avoid matching math inside them
        let codeBlockRanges: [NSRange] = children.compactMap { node in
            if case .codeBlock = node.type { return node.range }
            if case .inlineCode = node.type { return node.range }
            return nil
        }

        // Block math: $$...$$
        let blockMathPattern = try? NSRegularExpression(pattern: "\\$\\$([\\s\\S]*?)\\$\\$", options: [])
        let blockMatches = blockMathPattern?.matches(in: source, range: NSRange(location: 0, length: nsSource.length)) ?? []

        var mathNodes: [TymarkNode] = []
        for match in blockMatches {
            let fullRange = match.range

            // Skip matches inside front matter or code blocks
            if fullRange.location < fmEnd { continue }
            if codeBlockRanges.contains(where: { NSIntersectionRange($0, fullRange).length > 0 }) { continue }

            let contentRange = match.range(at: 1)
            let content = nsSource.substring(with: contentRange)
            mathNodes.append(TymarkNode(
                type: .math(display: true),
                content: content,
                range: fullRange
            ))
        }

        // Inline math: $...$  (single dollar, not preceded/followed by another $)
        let inlineMathPattern = try? NSRegularExpression(pattern: "(?<!\\$)\\$(?!\\$)([^$\\n]+?)(?<!\\$)\\$(?!\\$)", options: [])
        let inlineMatches = inlineMathPattern?.matches(in: source, range: NSRange(location: 0, length: nsSource.length)) ?? []

        for match in inlineMatches {
            let fullRange = match.range

            // Skip matches inside front matter or code blocks
            if fullRange.location < fmEnd { continue }
            if codeBlockRanges.contains(where: { NSIntersectionRange($0, fullRange).length > 0 }) { continue }

            let contentRange = match.range(at: 1)
            let content = nsSource.substring(with: contentRange)

            // Skip if this range overlaps with a block math
            let overlaps = blockMatches.contains { NSIntersectionRange($0.range, fullRange).length > 0 }
            if !overlaps {
                mathNodes.append(TymarkNode(
                    type: .math(display: false),
                    content: content,
                    range: fullRange
                ))
            }
        }

        // Merge math nodes into children (they'll be rendered alongside existing nodes)
        var result = children
        result.append(contentsOf: mathNodes)
        return result
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
            let localNode = convertNode(child, rangeSource: source, fullSource: source, baseLocation: 0)
            return offsetNode(localNode, by: location)
        }
        return TymarkNode(type: .paragraph, range: NSRange(location: location, length: source.count))
    }

    private func mergeBlock(
        oldRoot: TymarkNode,
        oldBlock: TymarkNode,
        newBlock: TymarkNode,
        editDelta: Int
    ) -> TymarkNode {
        // Replace the edited block and keep all sibling/ancestor ranges consistent.
        return replaceAndAdjust(
            in: oldRoot,
            replacing: oldBlock,
            with: newBlock,
            editDelta: editDelta
        )
    }

    private func replaceAndAdjust(
        in node: TymarkNode,
        replacing oldBlock: TymarkNode,
        with newBlock: TymarkNode,
        editDelta: Int
    ) -> TymarkNode {
        // Replace the matching subtree entirely.
        if node.id == oldBlock.id {
            return newBlock
        }

        let oldEnd = NSMaxRange(oldBlock.range)
        let oldStart = oldBlock.range.location

        // Recursively process children first.
        let adjustedChildren = node.children.map { child in
            replaceAndAdjust(in: child, replacing: oldBlock, with: newBlock, editDelta: editDelta)
        }

        // Then shift/resize current range as needed.
        var adjustedRange = node.range
        if node.range.location >= oldEnd {
            adjustedRange.location += editDelta
        } else if node.range.location <= oldStart && NSMaxRange(node.range) >= oldEnd {
            adjustedRange.length = max(0, node.range.length + editDelta)
        } else if NSIntersectionRange(node.range, oldBlock.range).length > 0 {
            let newEnd = max(node.range.location, NSMaxRange(node.range) + editDelta)
            adjustedRange.length = max(0, newEnd - node.range.location)
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

    private func offsetNode(_ node: TymarkNode, by delta: Int) -> TymarkNode {
        let shiftedRange = delta == 0
            ? node.range
            : NSRange(location: node.range.location + delta, length: node.range.length)

        let shiftedChildren = node.children.map { child in
            offsetNode(child, by: delta)
        }

        return TymarkNode(
            id: node.id,
            type: node.type,
            content: node.content,
            range: shiftedRange,
            children: shiftedChildren,
            metadata: node.metadata
        )
    }

    // MARK: - Node Conversion

    private func convertNode(_ node: Markup, rangeSource: String, fullSource: String, baseLocation: Int) -> TymarkNode {
        let range = node.range(in: rangeSource, baseLocation: baseLocation)

        switch node {
        case let document as Document:
            return convertDocument(document, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let paragraph as Paragraph:
            return convertParagraph(paragraph, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let heading as Heading:
            return convertHeading(heading, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let blockQuote as BlockQuote:
            return convertBlockQuote(blockQuote, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let list as UnorderedList:
            return convertList(list, ordered: false, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let list as OrderedList:
            return convertList(list, ordered: true, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let item as ListItem:
            return convertListItem(item, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let codeBlock as CodeBlock:
            return convertCodeBlock(codeBlock, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let inlineCode as InlineCode:
            return convertInlineCode(inlineCode, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let emphasis as Emphasis:
            return convertEmphasis(emphasis, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let strong as Strong:
            return convertStrong(strong, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let link as Link:
            return convertLink(link, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let image as Image:
            return convertImage(image, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let text as Markdown.Text:
            return convertText(text, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let softBreak as SoftBreak:
            return convertSoftBreak(softBreak, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let lineBreak as LineBreak:
            return convertLineBreak(lineBreak, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let thematicBreak as ThematicBreak:
            return convertThematicBreak(thematicBreak, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let table as Markdown.Table:
            return convertTable(table, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let tableRow as Markdown.Table.Row:
            return convertTableRow(tableRow, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let tableCell as Markdown.Table.Cell:
            return convertTableCell(tableCell, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let strikethrough as Strikethrough:
            return convertStrikethrough(strikethrough, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let html as InlineHTML:
            return convertInlineHTML(html, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        case let html as HTMLBlock:
            return convertHTMLBlock(html, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation, range: range)
        default:
            return TymarkNode(
                type: .custom(name: String(describing: type(of: node))),
                content: "",
                range: range,
                children: node.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
            )
        }
    }

    private func convertDocument(_ document: Document, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .document,
            content: "",
            range: range,
            children: document.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertParagraph(_ paragraph: Paragraph, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .paragraph,
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: paragraph.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertHeading(_ heading: Heading, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .heading(level: heading.level),
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: heading.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertBlockQuote(_ blockQuote: BlockQuote, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .blockquote,
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: blockQuote.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertList(_ list: ListItemContainer, ordered: Bool, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .list(ordered: ordered),
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: list.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertListItem(_ item: ListItem, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .listItem,
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: item.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertCodeBlock(_ codeBlock: CodeBlock, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .codeBlock(language: codeBlock.language),
            content: codeBlock.code,
            range: range,
            children: []
        )
    }

    private func convertInlineCode(_ inlineCode: InlineCode, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .inlineCode,
            content: inlineCode.code,
            range: range,
            children: []
        )
    }

    private func convertEmphasis(_ emphasis: Emphasis, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .emphasis,
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: emphasis.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertStrong(_ strong: Strong, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .strong,
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: strong.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertLink(_ link: Link, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .link(destination: link.destination ?? "", title: link.title),
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: link.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertImage(_ image: Image, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .image(source: image.source ?? "", alt: image.plainText),
            content: "",
            range: range,
            children: []
        )
    }

    private func convertText(_ text: Markdown.Text, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .text,
            content: text.string,
            range: range,
            children: []
        )
    }

    private func convertSoftBreak(_ softBreak: SoftBreak, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .softBreak,
            content: " ",
            range: range,
            children: []
        )
    }

    private func convertLineBreak(_ lineBreak: LineBreak, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .lineBreak,
            content: "\n",
            range: range,
            children: []
        )
    }

    private func convertThematicBreak(_ thematicBreak: ThematicBreak, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .thematicBreak,
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: []
        )
    }

    private func convertTable(_ table: Markdown.Table, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .table,
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: table.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertTableRow(_ row: Markdown.Table.Row, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .tableRow,
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: row.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertTableCell(_ cell: Markdown.Table.Cell, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .tableCell,
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: cell.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertStrikethrough(_ strikethrough: Strikethrough, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .strikethrough,
            content: extractContent(for: range, from: fullSource),
            range: range,
            children: strikethrough.children.map { convertNode($0, rangeSource: rangeSource, fullSource: fullSource, baseLocation: baseLocation) }
        )
    }

    private func convertInlineHTML(_ html: InlineHTML, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
        return TymarkNode(
            type: .html,
            content: html.rawHTML,
            range: range,
            children: []
        )
    }

    private func convertHTMLBlock(_ html: HTMLBlock, rangeSource: String, fullSource: String, baseLocation: Int, range: NSRange) -> TymarkNode {
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

            let nsSource = source as NSString
            let clampedStart = max(0, min(startOffset, nsSource.length))
            let clampedEnd = max(clampedStart, min(endOffset, nsSource.length))

            let location = baseLocation + clampedStart
            let length = max(0, clampedEnd - clampedStart)
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
