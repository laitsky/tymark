import Foundation
#if canImport(AppKit)
import AppKit
public typealias TymarkFont = NSFont
public typealias TymarkColor = NSColor
#elseif canImport(UIKit)
import UIKit
public typealias TymarkFont = UIFont
public typealias TymarkColor = UIColor
#endif

// MARK: - Rendering Attributes

public extension NSAttributedString.Key {
    static let tymarkNodeType = NSAttributedString.Key("TymarkNodeType")
    static let tymarkNodeID = NSAttributedString.Key("TymarkNodeID")
    static let tymarkSyntaxHidden = NSAttributedString.Key("TymarkSyntaxHidden")
    static let tymarkHeadingLevel = NSAttributedString.Key("TymarkHeadingLevel")
    static let tymarkCodeLanguage = NSAttributedString.Key("TymarkCodeLanguage")
    static let tymarkLinkDestination = NSAttributedString.Key("TymarkLinkDestination")
    static let tymarkImageSource = NSAttributedString.Key("TymarkImageSource")
}

public struct TymarkRenderingAttribute {
    public static let nodeTypeKey = NSAttributedString.Key.tymarkNodeType
    public static let nodeIDKey = NSAttributedString.Key.tymarkNodeID
    public static let isSyntaxHiddenKey = NSAttributedString.Key.tymarkSyntaxHidden
    public static let headingLevelKey = NSAttributedString.Key.tymarkHeadingLevel
    public static let codeLanguageKey = NSAttributedString.Key.tymarkCodeLanguage
    public static let linkDestinationKey = NSAttributedString.Key.tymarkLinkDestination
    public static let imageSourceKey = NSAttributedString.Key.tymarkImageSource
}

// MARK: - Rendering Context

public struct RenderingContext: @unchecked Sendable {
    public var isSourceMode: Bool
    public var headingFontSizes: [Int: CGFloat]
    public var baseFont: TymarkFont
    public var baseColor: TymarkColor
    public var codeFont: TymarkFont
    public var linkColor: TymarkColor
    public var syntaxHiddenColor: TymarkColor
    public var codeBackgroundColor: TymarkColor
    public var blockquoteColor: TymarkColor

    public static let `default` = RenderingContext(
        isSourceMode: false,
        headingFontSizes: [1: 32, 2: 24, 3: 20, 4: 17, 5: 15, 6: 14],
        baseFont: TymarkFont.systemFont(ofSize: 14),
        baseColor: {
            #if canImport(AppKit)
            return NSColor.labelColor
            #else
            return UIColor.label
            #endif
        }(),
        codeFont: TymarkFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        linkColor: {
            #if canImport(AppKit)
            return NSColor.linkColor
            #else
            return UIColor.link
            #endif
        }(),
        syntaxHiddenColor: {
            #if canImport(AppKit)
            return NSColor.secondaryLabelColor.withAlphaComponent(0.35)
            #else
            return UIColor.secondaryLabel.withAlphaComponent(0.35)
            #endif
        }(),
        codeBackgroundColor: {
            #if canImport(AppKit)
            return NSColor.textBackgroundColor.withAlphaComponent(0.4)
            #else
            return UIColor.secondarySystemBackground.withAlphaComponent(0.6)
            #endif
        }(),
        blockquoteColor: {
            #if canImport(AppKit)
            return NSColor.secondaryLabelColor
            #else
            return UIColor.secondaryLabel
            #endif
        }()
    )

    public init(
        isSourceMode: Bool = false,
        headingFontSizes: [Int: CGFloat] = [1: 32, 2: 24, 3: 20, 4: 17, 5: 15, 6: 14],
        baseFont: TymarkFont = TymarkFont.systemFont(ofSize: 14),
        baseColor: TymarkColor = {
            #if canImport(AppKit)
            return NSColor.labelColor
            #else
            return UIColor.label
            #endif
        }(),
        codeFont: TymarkFont = TymarkFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        linkColor: TymarkColor = {
            #if canImport(AppKit)
            return NSColor.linkColor
            #else
            return UIColor.link
            #endif
        }(),
        syntaxHiddenColor: TymarkColor = {
            #if canImport(AppKit)
            return NSColor.secondaryLabelColor.withAlphaComponent(0.35)
            #else
            return UIColor.secondaryLabel.withAlphaComponent(0.35)
            #endif
        }(),
        codeBackgroundColor: TymarkColor = {
            #if canImport(AppKit)
            return NSColor.textBackgroundColor.withAlphaComponent(0.4)
            #else
            return UIColor.secondarySystemBackground.withAlphaComponent(0.6)
            #endif
        }(),
        blockquoteColor: TymarkColor = {
            #if canImport(AppKit)
            return NSColor.secondaryLabelColor
            #else
            return UIColor.secondaryLabel
            #endif
        }()
    ) {
        self.isSourceMode = isSourceMode
        self.headingFontSizes = headingFontSizes
        self.baseFont = baseFont
        self.baseColor = baseColor
        self.codeFont = codeFont
        self.linkColor = linkColor
        self.syntaxHiddenColor = syntaxHiddenColor
        self.codeBackgroundColor = codeBackgroundColor
        self.blockquoteColor = blockquoteColor
    }
}

// MARK: - AST to Attributed String Converter

/// Renders markdown by **preserving the original source string** and applying attributes over it.
/// This avoids feedback loops and crashes caused by replacing the backing string while editing.
public final class ASTToAttributedString {
    private let context: RenderingContext

    public init(context: RenderingContext = .default) {
        self.context = context
    }

    public func convert(_ document: TymarkDocument) -> NSAttributedString {
        return render(source: document.source, root: document.root)
    }

    public func convertNode(_ node: TymarkNode, source: String) -> NSAttributedString {
        let rendered = render(source: source, root: node)
        let nsSource = source as NSString
        guard let clamped = Self.clamp(node.range, maxLength: nsSource.length) else {
            return NSAttributedString(string: "")
        }
        return rendered.attributedSubstring(from: clamped)
    }

    // MARK: - Rendering

    private func render(source: String, root: TymarkNode) -> NSAttributedString {
        let nsSource = source as NSString
        let attributed = NSMutableAttributedString(string: source)

        let fullRange = NSRange(location: 0, length: nsSource.length)
        attributed.addAttributes(
            [
                .font: context.baseFont,
                .foregroundColor: context.baseColor
            ],
            range: fullRange
        )

        applyNodeAttributes(root, to: attributed, nsSource: nsSource)
        return attributed
    }

    private func applyNodeAttributes(_ node: TymarkNode, to attributed: NSMutableAttributedString, nsSource: NSString) {
        let maxLength = nsSource.length

        if let range = Self.clamp(node.range, maxLength: maxLength) {
            safeAddAttributes(
                [
                    TymarkRenderingAttribute.nodeTypeKey: node.type,
                    TymarkRenderingAttribute.nodeIDKey: node.id.uuidString
                ],
                to: attributed,
                range: range,
                maxLength: maxLength
            )

            switch node.type {
            case .heading(let level):
                applyHeading(level: level, nodeRange: range, to: attributed, nsSource: nsSource)
            case .strong:
                safeAddAttributes([.font: fontByAddingTraits(boldTrait, to: context.baseFont)], to: attributed, range: range, maxLength: maxLength)
            case .emphasis:
                safeAddAttributes([.font: fontByAddingTraits(italicTrait, to: context.baseFont)], to: attributed, range: range, maxLength: maxLength)
            case .strikethrough:
                safeAddAttributes([.strikethroughStyle: NSUnderlineStyle.single.rawValue], to: attributed, range: range, maxLength: maxLength)
            case .inlineCode:
                applyInlineCode(nodeRange: range, to: attributed, nsSource: nsSource)
            case .codeBlock(let language):
                applyCodeBlock(language: language, nodeRange: range, to: attributed, nsSource: nsSource)
            case .link(let destination, _):
                safeAddAttributes(
                    [
                        .foregroundColor: context.linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        TymarkRenderingAttribute.linkDestinationKey: destination
                    ],
                    to: attributed,
                    range: range,
                    maxLength: maxLength
                )
            case .blockquote:
                applyBlockquote(nodeRange: range, to: attributed, nsSource: nsSource)
            case .frontMatter, .math, .mermaid:
                safeAddAttributes(
                    [
                        .font: context.codeFont,
                        .backgroundColor: context.codeBackgroundColor
                    ],
                    to: attributed,
                    range: range,
                    maxLength: maxLength
                )
            default:
                break
            }
        }

        for child in node.children {
            applyNodeAttributes(child, to: attributed, nsSource: nsSource)
        }
    }

    // MARK: - Node Styling

    private func applyHeading(level: Int, nodeRange: NSRange, to attributed: NSMutableAttributedString, nsSource: NSString) {
        let maxLength = nsSource.length
        let raw = nsSource.substring(with: nodeRange)
        let prefixLen = Self.headingPrefixLength(in: raw)

        let fontSize = context.headingFontSizes[level] ?? context.baseFont.pointSize
        let headingFont = TymarkFont.systemFont(ofSize: fontSize, weight: .bold)

        let contentRange = NSRange(location: nodeRange.location + prefixLen, length: max(0, nodeRange.length - prefixLen))
        safeAddAttributes(
            [
                .font: headingFont,
                TymarkRenderingAttribute.headingLevelKey: level
            ],
            to: attributed,
            range: contentRange,
            maxLength: maxLength
        )

        if !context.isSourceMode, prefixLen > 0 {
            let syntaxRange = NSRange(location: nodeRange.location, length: min(prefixLen, nodeRange.length))
            safeAddAttributes([.foregroundColor: context.syntaxHiddenColor], to: attributed, range: syntaxRange, maxLength: maxLength)
        }
    }

    private func applyInlineCode(nodeRange: NSRange, to attributed: NSMutableAttributedString, nsSource: NSString) {
        let maxLength = nsSource.length
        safeAddAttributes(
            [
                .font: context.codeFont,
                .backgroundColor: context.codeBackgroundColor
            ],
            to: attributed,
            range: nodeRange,
            maxLength: maxLength
        )

        if !context.isSourceMode {
            let raw = nsSource.substring(with: nodeRange)
            if raw.hasPrefix("`") && raw.hasSuffix("`") && raw.count >= 2 {
                safeAddAttributes([.foregroundColor: context.syntaxHiddenColor], to: attributed, range: NSRange(location: nodeRange.location, length: 1), maxLength: maxLength)
                safeAddAttributes([.foregroundColor: context.syntaxHiddenColor], to: attributed, range: NSRange(location: NSMaxRange(nodeRange) - 1, length: 1), maxLength: maxLength)
            }
        }
    }

    private func applyCodeBlock(language: String?, nodeRange: NSRange, to attributed: NSMutableAttributedString, nsSource: NSString) {
        let maxLength = nsSource.length
        safeAddAttributes(
            [
                .font: context.codeFont,
                .backgroundColor: context.codeBackgroundColor,
                TymarkRenderingAttribute.codeLanguageKey: language ?? ""
            ],
            to: attributed,
            range: nodeRange,
            maxLength: maxLength
        )

        // Hide ``` fences in non-source mode (best-effort).
        guard !context.isSourceMode else { return }
        let raw = nsSource.substring(with: nodeRange)
        let regex = try? NSRegularExpression(pattern: "(?m)^```.*$", options: [])
        let rawRange = NSRange(location: 0, length: (raw as NSString).length)
        let matches = regex?.matches(in: raw, range: rawRange) ?? []
        for match in matches {
            let fence = match.range
            let global = NSRange(location: nodeRange.location + fence.location, length: fence.length)
            safeAddAttributes([.foregroundColor: context.syntaxHiddenColor], to: attributed, range: global, maxLength: maxLength)
        }
    }

    private func applyBlockquote(nodeRange: NSRange, to attributed: NSMutableAttributedString, nsSource: NSString) {
        let maxLength = nsSource.length
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 18
        paragraphStyle.firstLineHeadIndent = 18
        paragraphStyle.paragraphSpacing = 4

        safeAddAttributes(
            [
                .foregroundColor: context.blockquoteColor,
                .paragraphStyle: paragraphStyle
            ],
            to: attributed,
            range: nodeRange,
            maxLength: maxLength
        )

        guard !context.isSourceMode else { return }

        let raw = nsSource.substring(with: nodeRange)
        let rawNS = raw as NSString
        let regex = try? NSRegularExpression(pattern: "(?m)^\\s*>\\s?", options: [])
        let matches = regex?.matches(in: raw, range: NSRange(location: 0, length: rawNS.length)) ?? []
        for match in matches {
            let local = match.range
            let global = NSRange(location: nodeRange.location + local.location, length: local.length)
            safeAddAttributes([.foregroundColor: context.syntaxHiddenColor], to: attributed, range: global, maxLength: maxLength)
        }
    }

    // MARK: - Utilities

    private func safeAddAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        to attributed: NSMutableAttributedString,
        range: NSRange,
        maxLength: Int
    ) {
        guard let clamped = Self.clamp(range, maxLength: maxLength) else { return }
        attributed.addAttributes(attributes, range: clamped)
    }

    private static func clamp(_ range: NSRange, maxLength: Int) -> NSRange? {
        guard maxLength > 0 else { return nil }
        let start = max(0, min(range.location, maxLength))
        let end = max(start, min(NSMaxRange(range), maxLength))
        let length = end - start
        guard length > 0 else { return nil }
        return NSRange(location: start, length: length)
    }

    private static func headingPrefixLength(in text: String) -> Int {
        // Count leading #...# and one following space if present.
        var idx = text.startIndex
        var countHashes = 0
        while idx < text.endIndex, text[idx] == "#" {
            countHashes += 1
            idx = text.index(after: idx)
        }
        // Consume one space after hashes.
        if idx < text.endIndex, text[idx] == " " {
            return countHashes + 1
        }
        return countHashes
    }

    private var boldTrait: TymarkFontDescriptorSymbolicTrait {
        #if canImport(AppKit)
        return .bold
        #else
        return .traitBold
        #endif
    }

    private var italicTrait: TymarkFontDescriptorSymbolicTrait {
        #if canImport(AppKit)
        return .italic
        #else
        return .traitItalic
        #endif
    }

    private func fontByAddingTraits(_ traits: TymarkFontDescriptorSymbolicTrait, to font: TymarkFont) -> TymarkFont {
        #if canImport(AppKit)
        var symbolic = font.fontDescriptor.symbolicTraits
        symbolic.formUnion(traits)
        let descriptor = font.fontDescriptor.withSymbolicTraits(symbolic) ?? font.fontDescriptor
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
        #else
        var symbolic = font.fontDescriptor.symbolicTraits
        symbolic.formUnion(traits)
        let descriptor = font.fontDescriptor.withSymbolicTraits(symbolic) ?? font.fontDescriptor
        return UIFont(descriptor: descriptor, size: font.pointSize)
        #endif
    }
}

#if canImport(AppKit)
private typealias TymarkFontDescriptorSymbolicTrait = NSFontDescriptor.SymbolicTraits
#else
private typealias TymarkFontDescriptorSymbolicTrait = UIFontDescriptor.SymbolicTraits
#endif
