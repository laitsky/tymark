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

public struct RenderingContext {
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
        headingFontSizes: [
            1: 32,
            2: 24,
            3: 20,
            4: 17,
            5: 15,
            6: 14
        ],
        baseFont: TymarkFont.systemFont(ofSize: 14),
        baseColor: TymarkColor.black,
        codeFont: TymarkFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        linkColor: TymarkColor(red: 0, green: 0.48, blue: 1, alpha: 1),
        syntaxHiddenColor: TymarkColor.black.withAlphaComponent(0.1),
        codeBackgroundColor: TymarkColor.white.withAlphaComponent(0.5),
        blockquoteColor: TymarkColor.gray
    )

    public init(
        isSourceMode: Bool = false,
        headingFontSizes: [Int: CGFloat] = [1: 32, 2: 24, 3: 20, 4: 17, 5: 15, 6: 14],
        baseFont: TymarkFont = TymarkFont.systemFont(ofSize: 14),
        baseColor: TymarkColor = TymarkColor.black,
        codeFont: TymarkFont = TymarkFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        linkColor: TymarkColor = TymarkColor(red: 0, green: 0.48, blue: 1, alpha: 1),
        syntaxHiddenColor: TymarkColor = TymarkColor.black.withAlphaComponent(0.1),
        codeBackgroundColor: TymarkColor = TymarkColor.white.withAlphaComponent(0.5),
        blockquoteColor: TymarkColor = TymarkColor.gray
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

public final class ASTToAttributedString {
    private let context: RenderingContext

    public init(context: RenderingContext = .default) {
        self.context = context
    }

    public func convert(_ document: TymarkDocument) -> NSAttributedString {
        return convertNode(document.root, source: document.source)
    }

    public func convertNode(_ node: TymarkNode, source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        switch node.type {
        case .document:
            for child in node.children {
                result.append(convertNode(child, source: source))
            }

        case .paragraph:
            for child in node.children {
                result.append(convertNode(child, source: source))
            }
            result.append(NSAttributedString(string: "\n"))

        case .heading(let level):
            result.append(convertHeading(node, level: level, source: source))
            result.append(NSAttributedString(string: "\n"))

        case .blockquote:
            result.append(convertBlockQuote(node, source: source))
            result.append(NSAttributedString(string: "\n"))

        case .list(let ordered):
            result.append(convertList(node, ordered: ordered, source: source))
            result.append(NSAttributedString(string: "\n"))

        case .listItem:
            result.append(convertListItem(node, source: source))

        case .codeBlock:
            result.append(convertCodeBlock(node, source: source))
            result.append(NSAttributedString(string: "\n"))

        case .inlineCode:
            result.append(convertInlineCode(node, source: source))

        case .emphasis:
            result.append(convertEmphasis(node, source: source))

        case .strong:
            result.append(convertStrong(node, source: source))

        case .link(let destination, _):
            result.append(convertLink(node, destination: destination, source: source))

        case .image:
            result.append(convertImage(node, source: source))

        case .text:
            result.append(convertText(node, source: source))

        case .softBreak:
            result.append(NSAttributedString(string: " "))

        case .lineBreak:
            result.append(NSAttributedString(string: "\n"))

        case .thematicBreak:
            result.append(convertThematicBreak(node, source: source))
            result.append(NSAttributedString(string: "\n"))

        case .table:
            result.append(convertTable(node, source: source))
            result.append(NSAttributedString(string: "\n"))

        case .tableRow:
            result.append(convertTableRow(node, source: source))
            result.append(NSAttributedString(string: "\n"))

        case .tableCell:
            result.append(convertTableCell(node, source: source))
            result.append(NSAttributedString(string: " | "))

        case .strikethrough:
            result.append(convertStrikethrough(node, source: source))

        case .html:
            result.append(convertHTML(node, source: source))

        case .custom:
            // Just render children for custom nodes
            for child in node.children {
                result.append(convertNode(child, source: source))
            }
        }

        // Apply base attributes to the entire range
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: context.baseFont,
            .foregroundColor: context.baseColor,
            TymarkRenderingAttribute.nodeTypeKey: node.type,
            TymarkRenderingAttribute.nodeIDKey: node.id.uuidString
        ]
        result.addAttributes(baseAttributes, range: NSRange(location: 0, length: result.length))

        return result
    }

    // MARK: - Element Converters

    private func convertHeading(_ node: TymarkNode, level: Int, source: String) -> NSAttributedString {
        let content = extractContent(node, from: source)
        let fontSize = context.headingFontSizes[level] ?? context.baseFont.pointSize
        let font = TymarkFont.systemFont(ofSize: fontSize, weight: .bold)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: context.baseColor,
            TymarkRenderingAttribute.nodeTypeKey: node.type,
            TymarkRenderingAttribute.headingLevelKey: level
        ]

        // Hide the markdown syntax (# characters) if not in source mode
        let result = NSMutableAttributedString()
        if !context.isSourceMode {
            // Just show the content without #
            let hashPrefix = String(repeating: "#", count: level) + " "
            let contentWithoutPrefix = content.hasPrefix(hashPrefix) ? String(content.dropFirst(hashPrefix.count)) : content
            let attributed = NSAttributedString(string: contentWithoutPrefix, attributes: attributes)
            result.append(attributed)
        } else {
            let attributed = NSAttributedString(string: content, attributes: attributes)
            result.append(attributed)
        }

        return result
    }

    private func convertBlockQuote(_ node: TymarkNode, source: String) -> NSAttributedString {
        let content = extractContent(node, from: source)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 20
        paragraphStyle.firstLineHeadIndent = 20

        let attributes: [NSAttributedString.Key: Any] = [
            .font: context.baseFont,
            .foregroundColor: context.blockquoteColor,
            .paragraphStyle: paragraphStyle
        ]

        // Remove the > prefix if not in source mode
        let result = NSMutableAttributedString()
        if !context.isSourceMode {
            let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
            var processedLines: [String] = []
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("> ") {
                    processedLines.append(String(trimmed.dropFirst(2)))
                } else if trimmed.hasPrefix(">") {
                    processedLines.append(String(trimmed.dropFirst(1)))
                } else {
                    processedLines.append(String(line))
                }
            }
            let processedContent = processedLines.joined(separator: "\n")
            let attributed = NSAttributedString(string: processedContent, attributes: attributes)
            result.append(attributed)
        } else {
            let attributed = NSAttributedString(string: content, attributes: attributes)
            result.append(attributed)
        }

        return result
    }

    private func convertList(_ node: TymarkNode, ordered: Bool, source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, child) in node.children.enumerated() {
            if child.type == .listItem {
                let marker = ordered ? "\(index + 1). " : "• "
                let attributedMarker = NSAttributedString(
                    string: marker,
                    attributes: [.font: context.baseFont, .foregroundColor: context.baseColor]
                )
                result.append(attributedMarker)

                // Convert list item children (skip the marker)
                for grandchild in child.children {
                    result.append(convertNode(grandchild, source: source))
                }
            }
        }

        return result
    }

    private func convertListItem(_ node: TymarkNode, source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in node.children {
            result.append(convertNode(child, source: source))
        }
        return result
    }

    private func convertCodeBlock(_ node: TymarkNode, source: String) -> NSAttributedString {
        let content = node.content
        let language = node.codeLanguage

        let attributes: [NSAttributedString.Key: Any] = [
            .font: context.codeFont,
            .foregroundColor: context.baseColor,
            .backgroundColor: context.codeBackgroundColor,
            TymarkRenderingAttribute.codeLanguageKey: language ?? ""
        ]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 10

        let result = NSMutableAttributedString(
            string: content,
            attributes: attributes.merging([.paragraphStyle: paragraphStyle]) { $1 }
        )

        return result
    }

    private func convertInlineCode(_ node: TymarkNode, source: String) -> NSAttributedString {
        let content = node.content

        // Remove backticks if not in source mode
        let displayContent: String
        if !context.isSourceMode {
            displayContent = content.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
        } else {
            displayContent = content
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: context.codeFont,
            .foregroundColor: context.baseColor,
            .backgroundColor: context.codeBackgroundColor
        ]

        return NSAttributedString(string: displayContent, attributes: attributes)
    }

    private func convertEmphasis(_ node: TymarkNode, source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in node.children {
            result.append(convertNode(child, source: source))
        }

        // Apply italic to the entire range
        #if canImport(AppKit)
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            if let font = value as? TymarkFont {
                let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                result.addAttribute(.font, value: italicFont, range: range)
            }
        }
        #else
        // On non-macOS platforms, use UIFontDescriptor for proper trait manipulation
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            if let font = value as? TymarkFont {
                let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? font.fontDescriptor
                let italicFont = TymarkFont(descriptor: descriptor, size: font.pointSize)
                result.addAttribute(.font, value: italicFont, range: range)
            }
        }
        #endif

        return result
    }

    private func convertStrong(_ node: TymarkNode, source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in node.children {
            result.append(convertNode(child, source: source))
        }

        // Apply bold to the entire range
        #if canImport(AppKit)
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            if let font = value as? TymarkFont {
                let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                result.addAttribute(.font, value: boldFont, range: range)
            }
        }
        #else
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            if let font = value as? TymarkFont {
                let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) ?? font.fontDescriptor
                let boldFont = TymarkFont(descriptor: descriptor, size: font.pointSize)
                result.addAttribute(.font, value: boldFont, range: range)
            }
        }
        #endif

        return result
    }

    private func convertLink(_ node: TymarkNode, destination: String, source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in node.children {
            result.append(convertNode(child, source: source))
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: context.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            TymarkRenderingAttribute.linkDestinationKey: destination
        ]

        result.addAttributes(attributes, range: NSRange(location: 0, length: result.length))

        return result
    }

    private func convertImage(_ node: TymarkNode, source: String) -> NSAttributedString {
        // Image data is stored in the type's associated values, not metadata
        let alt: String
        let src: String
        if case .image(let imageSource, let imageAlt) = node.type {
            src = imageSource
            alt = imageAlt ?? "image"
        } else {
            src = ""
            alt = "image"
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: context.linkColor,
            .backgroundColor: context.codeBackgroundColor,
            TymarkRenderingAttribute.imageSourceKey: src
        ]

        // Show alt text with image indicator
        return NSAttributedString(
            string: "[Image: \(alt)]",
            attributes: attributes
        )
    }

    private func convertText(_ node: TymarkNode, source: String) -> NSAttributedString {
        let content = node.content
        return NSAttributedString(string: content, attributes: [
            .font: context.baseFont,
            .foregroundColor: context.baseColor
        ])
    }

    private func convertThematicBreak(_ node: TymarkNode, source: String) -> NSAttributedString {
        return NSAttributedString(
            string: String(repeating: "—", count: 30),
            attributes: [
                .foregroundColor: TymarkColor.gray
            ]
        )
    }

    private func convertTable(_ node: TymarkNode, source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in node.children {
            result.append(convertNode(child, source: source))
        }

        return result
    }

    private func convertTableRow(_ node: TymarkNode, source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in node.children {
            result.append(convertNode(child, source: source))
        }

        return result
    }

    private func convertTableCell(_ node: TymarkNode, source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in node.children {
            result.append(convertNode(child, source: source))
        }

        // Add some padding attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: context.baseFont,
            .foregroundColor: context.baseColor
        ]

        result.addAttributes(attributes, range: NSRange(location: 0, length: result.length))

        return result
    }

    private func convertStrikethrough(_ node: TymarkNode, source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in node.children {
            result.append(convertNode(child, source: source))
        }

        result.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 0, length: result.length)
        )

        return result
    }

    private func convertHTML(_ node: TymarkNode, source: String) -> NSAttributedString {
        // For now, just render the HTML content as-is
        let content = node.content
        return NSAttributedString(
            string: content,
            attributes: [
                .font: context.codeFont,
                .foregroundColor: context.blockquoteColor
            ]
        )
    }

    // MARK: - Helpers

    private func extractContent(_ node: TymarkNode, from source: String) -> String {
        guard node.range.location >= 0 && node.range.length > 0 else {
            return node.content
        }
        guard let stringRange = Range(node.range, in: source) else {
            return node.content
        }
        return String(source[stringRange])
    }
}

// NOTE: Removed infinite-recursion NSMutableAttributedString.append extension.
// NSMutableAttributedString already has append(_:) — re-declaring it caused a stack overflow.
