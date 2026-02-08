import Foundation

// MARK: - AST Node Types

public enum TymarkNodeType: Equatable, Hashable {
    case document
    case paragraph
    case heading(level: Int)
    case blockquote
    case list(ordered: Bool)
    case listItem
    case codeBlock(language: String?)
    case inlineCode
    case emphasis
    case strong
    case link(destination: String, title: String?)
    case image(source: String, alt: String?)
    case text
    case softBreak
    case lineBreak
    case thematicBreak
    case table
    case tableRow
    case tableCell
    case strikethrough
    case html
    case custom(name: String)
}

// MARK: - AST Node

public struct TymarkNode: Identifiable, Equatable, Hashable {
    public let id: UUID
    public let type: TymarkNodeType
    public let content: String
    public let range: NSRange
    public let children: [TymarkNode]
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        type: TymarkNodeType,
        content: String = "",
        range: NSRange,
        children: [TymarkNode] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.range = range
        self.children = children
        self.metadata = metadata
    }

    public static func == (lhs: TymarkNode, rhs: TymarkNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.content == rhs.content &&
        NSEqualRanges(lhs.range, rhs.range) &&
        lhs.children == rhs.children &&
        lhs.metadata == rhs.metadata
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
        hasher.combine(content)
        hasher.combine(range.location)
        hasher.combine(range.length)
        hasher.combine(children)
        hasher.combine(metadata)
    }
}

// MARK: - Document

public struct TymarkDocument: Equatable, Hashable {
    public let root: TymarkNode
    public let source: String
    public let version: UUID

    public init(root: TymarkNode, source: String, version: UUID = UUID()) {
        self.root = root
        self.source = source
        self.version = version
    }
}

// MARK: - Helpers

extension TymarkNode {
    public var isBlock: Bool {
        switch type {
        case .document, .paragraph, .heading, .blockquote, .list, .listItem,
             .codeBlock, .thematicBreak, .table, .tableRow, .tableCell, .html:
            return true
        default:
            return false
        }
    }

    public var isInline: Bool {
        switch type {
        case .text, .emphasis, .strong, .inlineCode, .link, .image,
             .softBreak, .lineBreak, .strikethrough:
            return true
        default:
            return false
        }
    }

    public var headingLevel: Int? {
        if case .heading(let level) = type {
            return level
        }
        return nil
    }

    public var codeLanguage: String? {
        if case .codeBlock(let language) = type {
            return language
        }
        return nil
    }

    public func child(at path: [Int]) -> TymarkNode? {
        var current = self
        for index in path {
            guard index < current.children.count else { return nil }
            current = current.children[index]
        }
        return current
    }

    public func node(at location: Int) -> TymarkNode? {
        if NSLocationInRange(location, range) {
            for child in children {
                if let found = child.node(at: location) {
                    return found
                }
            }
            return self
        }
        return nil
    }
}
