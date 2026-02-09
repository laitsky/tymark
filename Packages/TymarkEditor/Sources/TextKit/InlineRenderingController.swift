import Cocoa
import TymarkParser

// MARK: - Inline Rendering Controller

@MainActor
public final class InlineRenderingController {

    // MARK: - Properties

    private let textStorage: NSTextStorage
    private var parserState: ParserState
    private var renderingContext: RenderingContext

    private var hiddenSyntaxRanges: [UUID: NSRange] = [:]
    private var isSourceMode = false

    // Threshold for showing syntax (characters before/after cursor)
    private let syntaxRevealThreshold = 1

    // MARK: - Initialization

    public init(textStorage: NSTextStorage, renderingContext: RenderingContext) {
        self.textStorage = textStorage
        self.parserState = ParserState()
        self.renderingContext = renderingContext
    }

    // MARK: - Public API

    public func setSource(_ source: String) {
        parserState.setSource(source)
        renderFullDocument()
    }

    public func updateSource(_ edit: TextEdit, newSource: String) {
        let _ = parserState.applyEdit(edit, to: newSource)

        // Determine if we can do an incremental update
        if shouldFullRender(edit) {
            renderFullDocument()
        } else {
            renderIncremental(at: edit.range)
        }
    }

    public func setSourceMode(_ enabled: Bool) {
        guard isSourceMode != enabled else { return }
        isSourceMode = enabled
        renderFullDocument()
    }

    public func revealSyntax(at location: Int) {
        guard let node = parserState.node(at: location) else { return }

        // Reveal syntax for this node
        revealSyntax(for: node)
    }

    public func hideSyntax(at location: Int) {
        guard let node = parserState.node(at: location) else { return }

        // Hide syntax for this node
        hideSyntax(for: node)
    }

    public func updateCursorLocation(_ location: Int) {
        // Find nodes near cursor
        let proximityRange = NSRange(
            location: max(0, location - syntaxRevealThreshold),
            length: syntaxRevealThreshold * 2
        )

        // Reveal syntax for nodes in proximity
        if let nodes = findNodesInRange(proximityRange) {
            for node in nodes {
                revealSyntax(for: node)
            }
        }

        // Hide syntax for nodes that are no longer near cursor
        hideDistantSyntax(from: location)
    }

    // MARK: - Rendering

    private func renderFullDocument() {
        let converter = ASTToAttributedString(context: renderingContext)
        let attributedString = converter.convert(parserState.document)

        textStorage.setAttributedString(attributedString)
    }

    private func renderIncremental(at range: NSRange) {
        // Current renderer preserves the original source string, so incremental replacement
        // would require carefully merging attributes. Keep it simple and safe: full re-render.
        renderFullDocument()
    }

    // MARK: - Syntax Visibility

    private func revealSyntax(for node: TymarkNode) {
        guard !isSourceMode else { return }
        guard hiddenSyntaxRanges[node.id] == nil else { return }

        // Determine syntax range
        guard let syntaxRange = computeSyntaxRange(for: node) else { return }

        hiddenSyntaxRanges[node.id] = syntaxRange

        // Apply visible color to syntax characters
        textStorage.addAttribute(
            .foregroundColor,
            value: renderingContext.baseColor,
            range: syntaxRange
        )
    }

    private func hideSyntax(for node: TymarkNode) {
        guard !isSourceMode else { return }
        guard let syntaxRange = hiddenSyntaxRanges[node.id] else { return }

        hiddenSyntaxRanges.removeValue(forKey: node.id)

        // Apply hidden color to syntax characters
        textStorage.addAttribute(
            .foregroundColor,
            value: renderingContext.syntaxHiddenColor,
            range: syntaxRange
        )
    }

    private func hideDistantSyntax(from cursorLocation: Int) {
        let proximityRange = NSRange(
            location: max(0, cursorLocation - syntaxRevealThreshold * 5),
            length: syntaxRevealThreshold * 10
        )

        for (nodeID, range) in hiddenSyntaxRanges {
            // Check if this range is still in proximity
            let intersection = NSIntersectionRange(range, proximityRange)
            if intersection.length == 0 {
                // Find the node and hide its syntax
                if let node = findNode(with: nodeID, in: parserState.document.root) {
                    hideSyntax(for: node)
                }
            }
        }
    }

    // MARK: - Helpers

    private func shouldFullRender(_ edit: TextEdit) -> Bool {
        // Check if this is a structural change
        let text = textStorage.string
        let nsText = text as NSString
        let safeLocation = max(0, min(edit.range.location, nsText.length))
        let safeLength = max(0, min(edit.range.length, nsText.length - safeLocation))
        let safeRange = NSRange(location: safeLocation, length: safeLength)
        let affectedText = safeLength > 0 ? nsText.substring(with: safeRange) : ""
        let changedText = affectedText + edit.replacement

        // Structural characters that trigger full re-render
        let structuralChars: Set<Character> = ["\n", "#", "-", "*", "_", "`", "[", "]", "(", ")", "|", ">"]

        for char in changedText {
            if structuralChars.contains(char) {
                return true
            }
        }

        // Check for large changes
        if max(edit.range.length, edit.replacement.count) > 100 {
            return true
        }

        return false
    }

    private func computeSyntaxRange(for node: TymarkNode) -> NSRange? {
        switch node.type {
        case .heading(let level):
            // Range of the # characters
            return NSRange(location: node.range.location, length: level + 1) // # + space

        case .strong:
            // Range of ** or __
            return NSRange(location: node.range.location, length: 2)

        case .emphasis:
            // Range of * or _
            return NSRange(location: node.range.location, length: 1)

        case .inlineCode:
            // Range of backticks
            return NSRange(location: node.range.location, length: 1)

        case .link:
            // Range of [ and ](...)
            // This is simplified - would need more complex logic
            return NSRange(location: node.range.location, length: 1)

        case .codeBlock:
            // Range of ``` and language identifier
            if let language = node.codeLanguage {
                return NSRange(location: node.range.location, length: 3 + language.count + 1)
            }
            return NSRange(location: node.range.location, length: 3)

        case .blockquote:
            // Range of > character
            return NSRange(location: node.range.location, length: 2) // > + space

        default:
            return nil
        }
    }

    private func findNodesInRange(_ range: NSRange) -> [TymarkNode]? {
        var results: [TymarkNode] = []

        func search(_ node: TymarkNode) {
            if NSIntersectionRange(node.range, range).length > 0 {
                results.append(node)
                for child in node.children {
                    search(child)
                }
            }
        }

        search(parserState.document.root)
        return results.isEmpty ? nil : results
    }

    private func findNode(with id: UUID, in node: TymarkNode) -> TymarkNode? {
        if node.id == id {
            return node
        }

        for child in node.children {
            if let found = findNode(with: id, in: child) {
                return found
            }
        }

        return nil
    }
}

// MARK: - Rendering Mode

public enum RenderingMode {
    case source      // Show raw markdown
    case rendered    // Show rendered output
    case hybrid      // Rendered with visible syntax near cursor
}

// MARK: - Render Cache

public final class RenderCache {
    private var cache: [String: NSAttributedString] = [:]
    private let maxCacheSize = 100
    private var accessOrder: [String] = []

    public func get(for key: String) -> NSAttributedString? {
        guard let value = cache[key] else { return nil }

        // Update access order
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)

        return value.copy() as? NSAttributedString
    }

    public func set(_ value: NSAttributedString, for key: String) {
        // Evict oldest if at capacity
        if cache.count >= maxCacheSize && !cache.keys.contains(key) {
            if let oldest = accessOrder.first {
                cache.removeValue(forKey: oldest)
                accessOrder.removeFirst()
            }
        }

        cache[key] = value.copy() as? NSAttributedString

        // Update access order
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    public func invalidate() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    public func invalidate(where predicate: (String) -> Bool) {
        for key in cache.keys where predicate(key) {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
    }
}
