import Foundation
import AppKit

// MARK: - Syntax Highlighter Protocol

public protocol SyntaxHighlighterProtocol {
    func highlight(_ code: String, language: String?) -> NSAttributedString
    func supportedLanguages() -> [String]
    func isLanguageSupported(_ language: String) -> Bool
}

// MARK: - Syntax Highlighter

public final class SyntaxHighlighter: SyntaxHighlighterProtocol {

    // MARK: - Properties

    private var languageDefinitions: [String: LanguageDefinition] = [:]
    private var theme: SyntaxTheme

    // MARK: - Initialization

    public init(theme: SyntaxTheme = .default) {
        self.theme = theme
        setupDefaultLanguages()
    }

    // MARK: - Public API

    public func highlight(_ code: String, language: String?) -> NSAttributedString {
        guard let language = language?.lowercased(),
              let definition = languageDefinitions[language] else {
            // Return plain attributed string for unknown languages
            return NSAttributedString(
                string: code,
                attributes: [.font: theme.font, .foregroundColor: theme.textColor]
            )
        }

        return highlightWithDefinition(code, definition: definition)
    }

    public func supportedLanguages() -> [String] {
        return Array(languageDefinitions.keys).sorted()
    }

    public func isLanguageSupported(_ language: String) -> Bool {
        return languageDefinitions[language.lowercased()] != nil
    }

    public func setTheme(_ newTheme: SyntaxTheme) {
        self.theme = newTheme
    }

    public func registerLanguage(_ language: String, definition: LanguageDefinition) {
        languageDefinitions[language.lowercased()] = definition
    }

    // MARK: - Private Methods

    private func setupDefaultLanguages() {
        // Swift
        registerLanguage("swift", definition: LanguageDefinition(
            name: "Swift",
            keywords: [
                "import", "class", "struct", "enum", "protocol", "extension",
                "func", "var", "let", "if", "else", "switch", "case", "default",
                "for", "while", "repeat", "in", "return", "break", "continue",
                "guard", "defer", "do", "catch", "throw", "throws", "try",
                "init", "deinit", "self", "super", "static", "final", "override",
                "public", "private", "internal", "fileprivate", "open",
                "mutating", "nonmutating", "associatedtype", "typealias",
                "async", "await", "actor", "sendable", "isolated"
            ],
            types: [
                "Int", "String", "Double", "Float", "Bool", "Array", "Dictionary",
                "Set", "Optional", "Any", "Void", "Character", "Range", "ClosedRange"
            ],
            operators: [
                "+", "-", "*", "/", "%", "=", "==", "!=", "<", ">", "<=", ">=",
                "&&", "||", "!", "&", "|", "^", "~", "<<", ">>", "??", "...", "..<"
            ],
            commentPrefix: "//",
            multilineCommentStart: "/*",
            multilineCommentEnd: "*/",
            stringDelimiter: "\"",
            escapeCharacter: "\\",
            numberPattern: "^\\d+\\.?\\d*"
        ))

        // Markdown
        registerLanguage("markdown", definition: LanguageDefinition(
            name: "Markdown",
            keywords: [],
            types: [],
            operators: [],
            commentPrefix: "<!--",
            multilineCommentStart: "<!--",
            multilineCommentEnd: "-->",
            stringDelimiter: "",
            escapeCharacter: "",
            numberPattern: ""
        ))

        // JSON
        registerLanguage("json", definition: LanguageDefinition(
            name: "JSON",
            keywords: ["true", "false", "null"],
            types: [],
            operators: [":", ","],
            commentPrefix: "",
            multilineCommentStart: "",
            multilineCommentEnd: "",
            stringDelimiter: "\"",
            escapeCharacter: "\\",
            numberPattern: "^-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?$"
        ))

        // Python
        registerLanguage("python", definition: LanguageDefinition(
            name: "Python",
            keywords: [
                "def", "class", "if", "elif", "else", "for", "while", "try",
                "except", "finally", "with", "as", "import", "from", "return",
                "yield", "lambda", "pass", "break", "continue", "raise", "assert",
                "del", "global", "nonlocal", "print", "None", "True", "False",
                "and", "or", "not", "in", "is", "async", "await"
            ],
            types: [
                "int", "str", "float", "bool", "list", "dict", "tuple", "set",
                "object", "type", "bytes", "bytearray"
            ],
            operators: [
                "+", "-", "*", "/", "//", "%", "**", "=", "==", "!=", "<", ">",
                "<=", ">=", "&", "|", "^", "~", "<<", ">>", "+=", "-=", "*=", "/="
            ],
            commentPrefix: "#",
            multilineCommentStart: "\"\"\"",
            multilineCommentEnd: "\"\"\"",
            stringDelimiter: "\"",
            escapeCharacter: "\\",
            numberPattern: "^\\d+\\.?\\d*([eE][+-]?\\d+)?$"
        ))

        // JavaScript
        registerLanguage("javascript", definition: LanguageDefinition(
            name: "JavaScript",
            keywords: [
                "function", "var", "let", "const", "if", "else", "for", "while",
                "do", "switch", "case", "default", "break", "continue", "return",
                "try", "catch", "finally", "throw", "new", "this", "typeof",
                "instanceof", "void", "delete", "in", "of", "class", "extends",
                "super", "import", "export", "from", "as", "async", "await",
                "yield", "static", "get", "set", "true", "false", "null", "undefined"
            ],
            types: [
                "Object", "Array", "String", "Number", "Boolean", "Function",
                "Date", "RegExp", "Error", "Promise", "Map", "Set", "Symbol",
                "WeakMap", "WeakSet", "ArrayBuffer", "SharedArrayBuffer"
            ],
            operators: [
                "+", "-", "*", "/", "%", "++", "--", "=", "==", "===", "!=", "!==",
                "<", ">", "<=", ">=", "&&", "||", "!", "&", "|", "^", "~",
                "<<", ">>", ">>>", "+=", "-=", "*=", "/=", "%=", "&=", "|=",
                "??", "?."
            ],
            commentPrefix: "//",
            multilineCommentStart: "/*",
            multilineCommentEnd: "*/",
            stringDelimiter: "\"",
            escapeCharacter: "\\",
            numberPattern: "^\\d+\\.?\\d*([eE][+-]?\\d+)?$"
        ))

        // HTML
        registerLanguage("html", definition: LanguageDefinition(
            name: "HTML",
            keywords: [],
            types: [],
            operators: [],
            commentPrefix: "",
            multilineCommentStart: "<!--",
            multilineCommentEnd: "-->",
            stringDelimiter: "\"",
            escapeCharacter: "&",
            numberPattern: ""
        ))

        // CSS
        registerLanguage("css", definition: LanguageDefinition(
            name: "CSS",
            keywords: [
                "@import", "@media", "@keyframes", "@font-face", "@supports",
                "color", "background", "border", "margin", "padding", "display",
                "position", "width", "height", "top", "left", "right", "bottom",
                "font", "text", "content", "float", "clear", "overflow", "visibility",
                "opacity", "z-index", "transform", "transition", "animation"
            ],
            types: [],
            operators: [":", ";", "{", "}", ",", ">", "+", "~"],
            commentPrefix: "",
            multilineCommentStart: "/*",
            multilineCommentEnd: "*/",
            stringDelimiter: "\"",
            escapeCharacter: "\\",
            numberPattern: "^\\d+(\\.\\d+)?(px|em|rem|%|vh|vw|pt|pc|in|cm|mm|ex|ch|vmin|vmax|fr)?$"
        ))

        // Shell/Bash
        registerLanguage("bash", definition: LanguageDefinition(
            name: "Bash",
            keywords: [
                "if", "then", "else", "elif", "fi", "case", "esac", "for",
                "do", "done", "while", "until", "function", "return", "exit",
                "echo", "export", "source", "alias", "unset", "readonly",
                "local", "declare", "typeset", "shift", "break", "continue",
                "true", "false", "test", "exec"
            ],
            types: [],
            operators: [
                "=", "==", "!=", "<", ">", "-eq", "-ne", "-lt", "-gt", "-le", "-ge",
                "&&", "||", "!", "|", "&", ";", ";;"
            ],
            commentPrefix: "#",
            multilineCommentStart: "",
            multilineCommentEnd: "",
            stringDelimiter: "\"",
            escapeCharacter: "\\",
            numberPattern: "^\\d+$"
        ))

        registerLanguage("sh", definition: languageDefinitions["bash"]!)
        registerLanguage("zsh", definition: languageDefinitions["bash"]!)
    }

    private func highlightWithDefinition(_ code: String, definition: LanguageDefinition) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: code, attributes: [
            .font: theme.font,
            .foregroundColor: theme.textColor
        ])

        // Apply highlighting based on patterns
        // This is a simplified regex-based highlighter

        let nsString = code as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // Keywords
        let keywordPattern = definition.keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        if let keywordRegex = try? NSRegularExpression(pattern: "\\b(\(keywordPattern))\\b", options: []) {
            keywordRegex.enumerateMatches(in: code, options: [], range: fullRange) { match, _, _ in
                guard let range = match?.range else { return }
                attributedString.addAttribute(.foregroundColor, value: theme.keywordColor, range: range)
            }
        }

        // Types
        let typePattern = definition.types.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        if !typePattern.isEmpty,
           let typeRegex = try? NSRegularExpression(pattern: "\\b(\(typePattern))\\b", options: []) {
            typeRegex.enumerateMatches(in: code, options: [], range: fullRange) { match, _, _ in
                guard let range = match?.range else { return }
                attributedString.addAttribute(.foregroundColor, value: theme.typeColor, range: range)
            }
        }

        // Strings
        if !definition.stringDelimiter.isEmpty {
            let escapedDelimiter = NSRegularExpression.escapedPattern(for: definition.stringDelimiter)
            let stringPattern = "\(escapedDelimiter)[^\(escapedDelimiter)]*\(escapedDelimiter)"
            if let stringRegex = try? NSRegularExpression(pattern: stringPattern, options: []) {
                stringRegex.enumerateMatches(in: code, options: [], range: fullRange) { match, _, _ in
                    guard let range = match?.range else { return }
                    attributedString.addAttribute(.foregroundColor, value: theme.stringColor, range: range)
                }
            }
        }

        // Comments
        if !definition.commentPrefix.isEmpty {
            let escapedPrefix = NSRegularExpression.escapedPattern(for: definition.commentPrefix)
            let commentPattern = "\(escapedPrefix).*"
            if let commentRegex = try? NSRegularExpression(pattern: commentPattern, options: []) {
                commentRegex.enumerateMatches(in: code, options: [], range: fullRange) { match, _, _ in
                    guard let range = match?.range else { return }
                    attributedString.addAttribute(.foregroundColor, value: theme.commentColor, range: range)
                }
            }
        }

        // Numbers
        if !definition.numberPattern.isEmpty,
           let numberRegex = try? NSRegularExpression(pattern: definition.numberPattern, options: []) {
            numberRegex.enumerateMatches(in: code, options: [], range: fullRange) { match, _, _ in
                guard let range = match?.range else { return }
                attributedString.addAttribute(.foregroundColor, value: theme.numberColor, range: range)
            }
        }

        return attributedString
    }
}

// MARK: - Language Definition

public struct LanguageDefinition {
    public let name: String
    public let keywords: [String]
    public let types: [String]
    public let operators: [String]
    public let commentPrefix: String
    public let multilineCommentStart: String
    public let multilineCommentEnd: String
    public let stringDelimiter: String
    public let escapeCharacter: String
    public let numberPattern: String

    public init(
        name: String,
        keywords: [String],
        types: [String],
        operators: [String],
        commentPrefix: String,
        multilineCommentStart: String,
        multilineCommentEnd: String,
        stringDelimiter: String,
        escapeCharacter: String,
        numberPattern: String
    ) {
        self.name = name
        self.keywords = keywords
        self.types = types
        self.operators = operators
        self.commentPrefix = commentPrefix
        self.multilineCommentStart = multilineCommentStart
        self.multilineCommentEnd = multilineCommentEnd
        self.stringDelimiter = stringDelimiter
        self.escapeCharacter = escapeCharacter
        self.numberPattern = numberPattern
    }
}

// MARK: - Syntax Theme

public struct SyntaxTheme: @unchecked Sendable {
    public var font: NSFont
    public var textColor: NSColor
    public var keywordColor: NSColor
    public var typeColor: NSColor
    public var stringColor: NSColor
    public var numberColor: NSColor
    public var commentColor: NSColor
    public var functionColor: NSColor
    public var operatorColor: NSColor

    public static let `default` = SyntaxTheme(
        font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        textColor: NSColor.black,
        keywordColor: NSColor(red: 0.67, green: 0.25, blue: 0.67, alpha: 1.0),     // Purple
        typeColor: NSColor(red: 0.93, green: 0.50, blue: 0.20, alpha: 1.0),        // Orange
        stringColor: NSColor(red: 0.90, green: 0.20, blue: 0.20, alpha: 1.0),       // Red
        numberColor: NSColor(red: 0.20, green: 0.60, blue: 0.90, alpha: 1.0),       // Blue
        commentColor: NSColor(red: 0.40, green: 0.60, blue: 0.40, alpha: 1.0),       // Green
        functionColor: NSColor(red: 0.55, green: 0.30, blue: 0.75, alpha: 1.0),     // Purple variant
        operatorColor: NSColor(red: 0.70, green: 0.35, blue: 0.15, alpha: 1.0)       // Brown/Orange
    )

    public init(
        font: NSFont,
        textColor: NSColor,
        keywordColor: NSColor,
        typeColor: NSColor,
        stringColor: NSColor,
        numberColor: NSColor,
        commentColor: NSColor,
        functionColor: NSColor,
        operatorColor: NSColor
    ) {
        self.font = font
        self.textColor = textColor
        self.keywordColor = keywordColor
        self.typeColor = typeColor
        self.stringColor = stringColor
        self.numberColor = numberColor
        self.commentColor = commentColor
        self.functionColor = functionColor
        self.operatorColor = operatorColor
    }
}

// MARK: - Language Provider

public final class LanguageProvider: @unchecked Sendable {
    public static let shared = LanguageProvider()

    private let languageAliases: [String: String] = [
        "js": "javascript",
        "ts": "typescript",
        "py": "python",
        "rb": "ruby",
        "cpp": "c++",
        "h": "c",
        "hpp": "c++",
        "md": "markdown",
        "mdown": "markdown",
        "mkd": "markdown",
        "yml": "yaml",
        "sh": "bash",
        "zsh": "bash",
        "fish": "bash",
        "bash": "bash",
        "shell": "bash"
    ]

    public func canonicalLanguageName(from identifier: String?) -> String? {
        guard let identifier = identifier?.lowercased() else { return nil }

        // Check aliases
        if let canonical = languageAliases[identifier] {
            return canonical
        }

        return identifier
    }

    public func detectLanguage(from filename: String) -> String? {
        let ext = (filename as NSString).pathExtension.lowercased()
        return canonicalLanguageName(from: ext)
    }

    public func detectLanguage(fromContent content: String) -> String? {
        // Simple heuristics for language detection
        if content.contains("import Swift") || content.contains("func ") && content.contains("var ") {
            return "swift"
        }
        if content.contains("def ") && content.contains(":") {
            return "python"
        }
        if content.contains("function") || content.contains("const ") || content.contains("let ") {
            return "javascript"
        }
        if content.contains("<?php") {
            return "php"
        }
        if content.contains("package main") || content.contains("func main()") {
            return "go"
        }
        if content.contains("#include") || content.contains("int main(") {
            return "c"
        }

        return nil
    }
}
