import Foundation

// MARK: - Incremental Parser

public final class IncrementalParser: @unchecked Sendable {
    private let baseParser: MarkdownParser
    private let diffEngine: ASTDiff

    public init(configuration: ParserConfiguration = .default) {
        self.baseParser = MarkdownParser(configuration: configuration)
        self.diffEngine = ASTDiff()
    }

    // MARK: - Public API

    public func parse(_ source: String) -> TymarkDocument {
        return baseParser.parse(source)
    }

    public func update(
        document: TymarkDocument,
        with edit: TextEdit,
        newSource: String
    ) -> (document: TymarkDocument, updateInfo: IncrementalUpdateInfo) {
        // Compute the full new document
        let newDocument = baseParser.parseIncremental(
            previousDocument: document,
            editRange: edit.range,
            newSource: newSource
        )

        // Compute the diff and update info
        let updateInfo = diffEngine.computeIncrementalUpdate(
            from: document,
            to: newDocument,
            editRange: edit.range
        )

        return (newDocument, updateInfo)
    }

    // MARK: - Block-Level Parsing

    public func reparseBlock(
        containing location: Int,
        in document: TymarkDocument,
        with newSource: String
    ) -> TymarkDocument? {
        // Find the block at the given location
        guard let block = findBlock(at: location, in: document.root) else {
            return nil
        }

        // Extract the block's source from the new source
        let blockSource = extractSource(for: block.range, from: newSource)

        // Parse just this block
        let parsedBlock = parseBlock(blockSource, at: block.range.location)

        // Create a new document with the updated block
        let newRoot = replaceBlock(block, with: parsedBlock, in: document.root, delta: newSource.count - document.source.count)

        return TymarkDocument(root: newRoot, source: newSource)
    }

    // MARK: - Private Methods

    private func findBlock(at location: Int, in node: TymarkNode) -> TymarkNode? {
        if !NSLocationInRange(location, node.range) && location != node.range.location {
            return nil
        }

        // Check children first (depth-first, preferring smaller blocks)
        for child in node.children.sorted(by: { $0.range.length < $1.range.length }) where child.isBlock {
            if let found = findBlock(at: location, in: child) {
                return found
            }
        }

        return node.isBlock ? node : nil
    }

    private func extractSource(for range: NSRange, from source: String) -> String {
        guard range.location >= 0 && range.length >= 0 else { return "" }
        guard let stringRange = Range(range, in: source) else { return "" }
        return String(source[stringRange])
    }

    private func parseBlock(_ source: String, at location: Int) -> TymarkNode {
        // Use the base parser but extract just the first block
        let tempDoc = baseParser.parse(source)

        // Find the first block child of the root
        if let firstBlock = tempDoc.root.children.first(where: { $0.isBlock }) {
            // Adjust the range to be absolute
            return TymarkNode(
                id: firstBlock.id,
                type: firstBlock.type,
                content: firstBlock.content,
                range: NSRange(
                    location: firstBlock.range.location + location,
                    length: firstBlock.range.length
                ),
                children: adjustRanges(in: firstBlock.children, delta: location),
                metadata: firstBlock.metadata
            )
        }

        // Fallback: treat as paragraph
        return TymarkNode(
            type: .paragraph,
            content: source,
            range: NSRange(location: location, length: source.count),
            children: []
        )
    }

    private func adjustRanges(in nodes: [TymarkNode], delta: Int) -> [TymarkNode] {
        return nodes.map { node in
            TymarkNode(
                id: node.id,
                type: node.type,
                content: node.content,
                range: NSRange(location: node.range.location + delta, length: node.range.length),
                children: adjustRanges(in: node.children, delta: delta),
                metadata: node.metadata
            )
        }
    }

    private func replaceBlock(
        _ oldBlock: TymarkNode,
        with newBlock: TymarkNode,
        in root: TymarkNode,
        delta: Int
    ) -> TymarkNode {
        // Rebuild the tree with the new block
        return replaceNode(oldBlock, with: newBlock, in: root, delta: delta)
    }

    private func replaceNode(
        _ target: TymarkNode,
        with replacement: TymarkNode,
        in node: TymarkNode,
        delta: Int
    ) -> TymarkNode {
        // Check if this is the target node
        if node.id == target.id {
            return replacement
        }

        // Process children
        let newChildren = node.children.map { child in
            replaceNode(target, with: replacement, in: child, delta: delta)
        }

        // Adjust range if this node starts at or after the end of the replaced block
        var newRange = node.range
        let lengthDelta = replacement.range.length - target.range.length
        if node.range.location >= NSMaxRange(target.range) {
            // Node is entirely after the replacement — shift by delta
            newRange = NSRange(
                location: node.range.location + lengthDelta,
                length: node.range.length
            )
        } else if node.range.location > target.range.location {
            // Node overlaps the replacement — adjust length
            newRange = NSRange(
                location: node.range.location + lengthDelta,
                length: max(0, node.range.length)
            )
        }

        return TymarkNode(
            id: node.id,
            type: node.type,
            content: node.content,
            range: newRange,
            children: newChildren,
            metadata: node.metadata
        )
    }
}

// MARK: - Text Edit

public struct TextEdit {
    public let range: NSRange
    public let replacement: String
    public let timestamp: Date

    public init(range: NSRange, replacement: String, timestamp: Date = Date()) {
        self.range = range
        self.replacement = replacement
        self.timestamp = timestamp
    }

    public var resultingRange: NSRange {
        return NSRange(location: range.location, length: replacement.count)
    }
}

// MARK: - Parser State

@MainActor
public final class ParserState {
    public private(set) var document: TymarkDocument
    private let parser: IncrementalParser
    private var editHistory: [TextEdit] = []
    private let maxHistorySize = 100

    public init(parser: IncrementalParser = IncrementalParser()) {
        self.parser = parser
        self.document = TymarkDocument(
            root: TymarkNode(type: .document, range: NSRange(location: 0, length: 0)),
            source: ""
        )
    }

    public func setSource(_ source: String) {
        document = parser.parse(source)
    }

    @discardableResult
    public func applyEdit(_ edit: TextEdit, to source: String) -> IncrementalUpdateInfo {
        editHistory.append(edit)
        if editHistory.count > maxHistorySize {
            editHistory.removeFirst()
        }

        let (newDoc, updateInfo) = parser.update(document: document, with: edit, newSource: source)
        document = newDoc
        return updateInfo
    }

    public func node(at location: Int) -> TymarkNode? {
        return document.root.node(at: location)
    }

    public func block(at location: Int) -> TymarkNode? {
        var current: TymarkNode? = document.root
        while let node = current {
            if let child = node.children.first(where: { $0.isBlock && NSLocationInRange(location, $0.range) }) {
                current = child
            } else {
                return node.isBlock ? node : nil
            }
        }
        return nil
    }
}
