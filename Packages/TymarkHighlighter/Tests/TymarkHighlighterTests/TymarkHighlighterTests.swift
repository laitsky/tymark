#if canImport(XCTest)
import XCTest
import AppKit
@testable import TymarkHighlighter

// MARK: - SyntaxHighlighter Tests

final class SyntaxHighlighterTests: XCTestCase {

    // MARK: - Initialization

    func testInitializationWithDefaultTheme() {
        let highlighter = SyntaxHighlighter()
        let languages = highlighter.supportedLanguages()
        XCTAssertFalse(languages.isEmpty, "Highlighter should register default languages on init")
    }

    func testInitializationWithCustomTheme() {
        let customTheme = SyntaxTheme(
            font: NSFont.systemFont(ofSize: 16),
            textColor: .white,
            keywordColor: .red,
            typeColor: .blue,
            stringColor: .green,
            numberColor: .orange,
            commentColor: .gray,
            functionColor: .purple,
            operatorColor: .brown
        )
        let highlighter = SyntaxHighlighter(theme: customTheme)
        XCTAssertFalse(highlighter.supportedLanguages().isEmpty)
    }

    // MARK: - supportedLanguages

    func testSupportedLanguagesReturnsNonEmptyList() {
        let highlighter = SyntaxHighlighter()
        let languages = highlighter.supportedLanguages()
        XCTAssertFalse(languages.isEmpty)
    }

    func testSupportedLanguagesReturnsSortedList() {
        let highlighter = SyntaxHighlighter()
        let languages = highlighter.supportedLanguages()
        XCTAssertEqual(languages, languages.sorted(), "Supported languages should be sorted alphabetically")
    }

    func testSupportedLanguagesIncludesSwift() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.supportedLanguages().contains("swift"))
    }

    func testSupportedLanguagesIncludesPython() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.supportedLanguages().contains("python"))
    }

    func testSupportedLanguagesIncludesJavaScript() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.supportedLanguages().contains("javascript"))
    }

    func testSupportedLanguagesIncludesJSON() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.supportedLanguages().contains("json"))
    }

    func testSupportedLanguagesIncludesHTML() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.supportedLanguages().contains("html"))
    }

    func testSupportedLanguagesIncludesCSS() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.supportedLanguages().contains("css"))
    }

    func testSupportedLanguagesIncludesBash() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.supportedLanguages().contains("bash"))
    }

    func testSupportedLanguagesIncludesMarkdown() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.supportedLanguages().contains("markdown"))
    }

    func testSupportedLanguagesIncludesSh() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.supportedLanguages().contains("sh"))
    }

    func testSupportedLanguagesIncludesZsh() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.supportedLanguages().contains("zsh"))
    }

    // MARK: - isLanguageSupported

    func testIsLanguageSupportedLowercase() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.isLanguageSupported("swift"))
    }

    func testIsLanguageSupportedMixedCase() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.isLanguageSupported("Swift"), "isLanguageSupported should be case-insensitive")
    }

    func testIsLanguageSupportedUppercase() {
        let highlighter = SyntaxHighlighter()
        XCTAssertTrue(highlighter.isLanguageSupported("SWIFT"), "isLanguageSupported should be case-insensitive")
    }

    func testIsLanguageSupportedReturnsFalseForUnknown() {
        let highlighter = SyntaxHighlighter()
        XCTAssertFalse(highlighter.isLanguageSupported("brainfuck"))
    }

    func testIsLanguageSupportedReturnsFalseForEmptyString() {
        let highlighter = SyntaxHighlighter()
        XCTAssertFalse(highlighter.isLanguageSupported(""))
    }

    // MARK: - highlight

    func testHighlightWithNilLanguageReturnsPlainAttributedString() {
        let highlighter = SyntaxHighlighter()
        let code = "some plain text"
        let result = highlighter.highlight(code, language: nil)
        XCTAssertEqual(result.string, code)
    }

    func testHighlightWithNilLanguageHasThemeFont() {
        let highlighter = SyntaxHighlighter()
        let code = "some plain text"
        let result = highlighter.highlight(code, language: nil)
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let font = attributes[.font] as? NSFont
        XCTAssertEqual(font, SyntaxTheme.default.font)
    }

    func testHighlightWithNilLanguageHasThemeTextColor() {
        let highlighter = SyntaxHighlighter()
        let code = "some plain text"
        let result = highlighter.highlight(code, language: nil)
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.textColor)
    }

    func testHighlightWithUnknownLanguageReturnsPlainAttributedString() {
        let highlighter = SyntaxHighlighter()
        let code = "some code in an unknown language"
        let result = highlighter.highlight(code, language: "brainfuck")
        XCTAssertEqual(result.string, code)
    }

    func testHighlightWithUnknownLanguageHasThemeFont() {
        let highlighter = SyntaxHighlighter()
        let code = "some code"
        let result = highlighter.highlight(code, language: "unknownlang")
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let font = attributes[.font] as? NSFont
        XCTAssertEqual(font, SyntaxTheme.default.font)
    }

    func testHighlightWithUnknownLanguageHasThemeTextColor() {
        let highlighter = SyntaxHighlighter()
        let code = "some code"
        let result = highlighter.highlight(code, language: "unknownlang")
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.textColor)
    }

    func testHighlightResultLengthMatchesInput() {
        let highlighter = SyntaxHighlighter()
        let code = "func hello() {\n    let x = 42\n}"
        let result = highlighter.highlight(code, language: "swift")
        XCTAssertEqual(result.string.count, code.count, "Highlighted result string length should match input length")
    }

    func testHighlightResultStringMatchesInput() {
        let highlighter = SyntaxHighlighter()
        let code = "func hello() {\n    let x = 42\n}"
        let result = highlighter.highlight(code, language: "swift")
        XCTAssertEqual(result.string, code, "Highlighted result should preserve the original code string")
    }

    func testHighlightSwiftKeywordFuncHasKeywordColor() {
        let highlighter = SyntaxHighlighter()
        let code = "func hello() {}"
        let result = highlighter.highlight(code, language: "swift")
        // "func" is at range 0..<4
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.keywordColor, "The keyword 'func' should be highlighted with the keyword color")
    }

    func testHighlightSwiftKeywordLetHasKeywordColor() {
        let highlighter = SyntaxHighlighter()
        let code = "let x = 10"
        let result = highlighter.highlight(code, language: "swift")
        // "let" is at range 0..<3
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.keywordColor, "The keyword 'let' should be highlighted with the keyword color")
    }

    func testHighlightSwiftKeywordVarHasKeywordColor() {
        let highlighter = SyntaxHighlighter()
        let code = "var x = 10"
        let result = highlighter.highlight(code, language: "swift")
        // "var" is at range 0..<3
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.keywordColor, "The keyword 'var' should be highlighted with the keyword color")
    }

    func testHighlightSwiftTypeIntHasTypeColor() {
        let highlighter = SyntaxHighlighter()
        let code = "let x: Int = 10"
        let result = highlighter.highlight(code, language: "swift")
        // "Int" starts at index 7
        let intRange = (code as NSString).range(of: "Int")
        XCTAssertNotEqual(intRange.location, NSNotFound)
        let attributes = result.attributes(at: intRange.location, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.typeColor, "The type 'Int' should be highlighted with the type color")
    }

    func testHighlightSwiftTypeStringHasTypeColor() {
        let highlighter = SyntaxHighlighter()
        // Use a context where String appears as a word boundary type, not inside a string literal
        let code = "var name: String"
        let result = highlighter.highlight(code, language: "swift")
        let stringRange = (code as NSString).range(of: "String")
        XCTAssertNotEqual(stringRange.location, NSNotFound)
        let attributes = result.attributes(at: stringRange.location, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.typeColor, "The type 'String' should be highlighted with the type color")
    }

    func testHighlightSwiftCommentHasCommentColor() {
        let highlighter = SyntaxHighlighter()
        let code = "// this is a comment"
        let result = highlighter.highlight(code, language: "swift")
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.commentColor, "Comments should be highlighted with the comment color")
    }

    func testHighlightSwiftCommentMidLineHasCommentColor() {
        let highlighter = SyntaxHighlighter()
        let code = "let x = 1 // inline comment"
        let result = highlighter.highlight(code, language: "swift")
        let commentStart = (code as NSString).range(of: "//")
        XCTAssertNotEqual(commentStart.location, NSNotFound)
        let attributes = result.attributes(at: commentStart.location, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.commentColor, "Inline comments should be highlighted with the comment color")
    }

    func testHighlightSwiftStringLiteralHasStringColor() {
        let highlighter = SyntaxHighlighter()
        let code = "let greeting = \"hello world\""
        let result = highlighter.highlight(code, language: "swift")
        let stringLiteralRange = (code as NSString).range(of: "\"hello world\"")
        XCTAssertNotEqual(stringLiteralRange.location, NSNotFound)
        let attributes = result.attributes(at: stringLiteralRange.location, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.stringColor, "String literals should be highlighted with the string color")
    }

    func testHighlightSwiftNumberLiteralHasNumberColor() {
        let highlighter = SyntaxHighlighter()
        let code = "let x = 42"
        let result = highlighter.highlight(code, language: "swift")
        let numberRange = (code as NSString).range(of: "42")
        XCTAssertNotEqual(numberRange.location, NSNotFound)
        let attributes = result.attributes(at: numberRange.location, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.numberColor, "Numeric literals should be highlighted with the number color")
    }

    func testHighlightLanguageWithNoKeywordsKeepsDefaultTextColor() {
        let highlighter = SyntaxHighlighter()
        let code = "plain markdown text"
        let result = highlighter.highlight(code, language: "markdown")
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.textColor, "Languages with no keywords should not tint plain text as keywords")
    }

    func testHighlightEmptyStringReturnsEmptyAttributedString() {
        let highlighter = SyntaxHighlighter()
        let result = highlighter.highlight("", language: "swift")
        XCTAssertEqual(result.string, "")
        XCTAssertEqual(result.length, 0)
    }

    func testHighlightPythonCommentHasCommentColor() {
        let highlighter = SyntaxHighlighter()
        let code = "# python comment"
        let result = highlighter.highlight(code, language: "python")
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.commentColor, "Python comments should be highlighted with the comment color")
    }

    func testHighlightIsCaseInsensitiveForLanguage() {
        let highlighter = SyntaxHighlighter()
        let code = "func test() {}"
        let resultLower = highlighter.highlight(code, language: "swift")
        let resultUpper = highlighter.highlight(code, language: "Swift")
        // Both should produce the same highlighting
        XCTAssertEqual(resultLower.string, resultUpper.string)
        let attrsLower = resultLower.attributes(at: 0, effectiveRange: nil)
        let attrsUpper = resultUpper.attributes(at: 0, effectiveRange: nil)
        let colorLower = attrsLower[.foregroundColor] as? NSColor
        let colorUpper = attrsUpper[.foregroundColor] as? NSColor
        XCTAssertEqual(colorLower, colorUpper, "Language name should be case insensitive for highlighting")
    }

    // MARK: - registerLanguage

    func testRegisterLanguageAddsNewLanguage() {
        let highlighter = SyntaxHighlighter()
        let customDef = LanguageDefinition(
            name: "CustomLang",
            keywords: ["custom", "keyword"],
            types: ["CustomType"],
            operators: ["+", "-"],
            commentPrefix: "//",
            multilineCommentStart: "/*",
            multilineCommentEnd: "*/",
            stringDelimiter: "\"",
            escapeCharacter: "\\",
            numberPattern: "\\d+"
        )
        XCTAssertFalse(highlighter.isLanguageSupported("customlang"))
        highlighter.registerLanguage("customlang", definition: customDef)
        XCTAssertTrue(highlighter.isLanguageSupported("customlang"), "Registered language should be supported")
    }

    func testRegisterLanguageAppearsInSupportedLanguages() {
        let highlighter = SyntaxHighlighter()
        let customDef = LanguageDefinition(
            name: "TestLang",
            keywords: ["test"],
            types: [],
            operators: [],
            commentPrefix: "#",
            multilineCommentStart: "",
            multilineCommentEnd: "",
            stringDelimiter: "'",
            escapeCharacter: "\\",
            numberPattern: ""
        )
        highlighter.registerLanguage("testlang", definition: customDef)
        XCTAssertTrue(highlighter.supportedLanguages().contains("testlang"))
    }

    func testRegisterLanguageStoresLowercased() {
        let highlighter = SyntaxHighlighter()
        let customDef = LanguageDefinition(
            name: "MixedCase",
            keywords: ["mixed"],
            types: [],
            operators: [],
            commentPrefix: "",
            multilineCommentStart: "",
            multilineCommentEnd: "",
            stringDelimiter: "",
            escapeCharacter: "",
            numberPattern: ""
        )
        highlighter.registerLanguage("MixedCase", definition: customDef)
        XCTAssertTrue(highlighter.isLanguageSupported("mixedcase"), "registerLanguage should store the key lowercased")
    }

    func testRegisterLanguageCanHighlightNewLanguage() {
        let highlighter = SyntaxHighlighter()
        let customDef = LanguageDefinition(
            name: "MyLang",
            keywords: ["mykey"],
            types: [],
            operators: [],
            commentPrefix: "#",
            multilineCommentStart: "",
            multilineCommentEnd: "",
            stringDelimiter: "\"",
            escapeCharacter: "\\",
            numberPattern: ""
        )
        highlighter.registerLanguage("mylang", definition: customDef)
        let result = highlighter.highlight("mykey value", language: "mylang")
        // The keyword "mykey" should have keyword color
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.keywordColor, "Registered language keywords should be highlighted")
    }

    func testRegisterLanguageAnchoredNumberPatternHighlightsInlineNumber() {
        let highlighter = SyntaxHighlighter()
        let customDef = LanguageDefinition(
            name: "AnchoredNumbers",
            keywords: [],
            types: [],
            operators: [],
            commentPrefix: "",
            multilineCommentStart: "",
            multilineCommentEnd: "",
            stringDelimiter: "",
            escapeCharacter: "",
            numberPattern: "^\\d+$"
        )
        highlighter.registerLanguage("anchored-numbers", definition: customDef)

        let code = "value 99"
        let result = highlighter.highlight(code, language: "anchored-numbers")
        let numberRange = (code as NSString).range(of: "99")
        XCTAssertNotEqual(numberRange.location, NSNotFound)
        let attributes = result.attributes(at: numberRange.location, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, SyntaxTheme.default.numberColor)
    }

    // MARK: - setTheme

    func testSetThemeChangesHighlightingColors() {
        let highlighter = SyntaxHighlighter()
        let customTheme = SyntaxTheme(
            font: NSFont.systemFont(ofSize: 20),
            textColor: .white,
            keywordColor: .cyan,
            typeColor: .magenta,
            stringColor: .yellow,
            numberColor: .orange,
            commentColor: .gray,
            functionColor: .systemPink,
            operatorColor: .brown
        )
        highlighter.setTheme(customTheme)

        let code = "func test() {}"
        let result = highlighter.highlight(code, language: "swift")
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.cyan, "After setTheme, keywords should use the new theme's keyword color")
    }

    func testSetThemeChangesFont() {
        let highlighter = SyntaxHighlighter()
        let customFont = NSFont.systemFont(ofSize: 24)
        let customTheme = SyntaxTheme(
            font: customFont,
            textColor: .white,
            keywordColor: .red,
            typeColor: .blue,
            stringColor: .green,
            numberColor: .orange,
            commentColor: .gray,
            functionColor: .purple,
            operatorColor: .brown
        )
        highlighter.setTheme(customTheme)

        let result = highlighter.highlight("hello", language: nil)
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let font = attributes[.font] as? NSFont
        XCTAssertEqual(font, customFont, "After setTheme, font should use the new theme's font")
    }

    func testSetThemeChangesTextColorForUnknownLanguage() {
        let highlighter = SyntaxHighlighter()
        let customTheme = SyntaxTheme(
            font: NSFont.systemFont(ofSize: 13),
            textColor: .yellow,
            keywordColor: .red,
            typeColor: .blue,
            stringColor: .green,
            numberColor: .orange,
            commentColor: .gray,
            functionColor: .purple,
            operatorColor: .brown
        )
        highlighter.setTheme(customTheme)

        let result = highlighter.highlight("plain text", language: "unknownlang")
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.yellow, "After setTheme, unknown language text should use the new theme's text color")
    }
}

// MARK: - SyntaxTheme Tests

final class SyntaxThemeTests: XCTestCase {

    func testDefaultThemeHasNonNilFont() {
        let theme = SyntaxTheme.default
        XCTAssertNotNil(theme.font)
    }

    func testDefaultThemeHasNonNilTextColor() {
        let theme = SyntaxTheme.default
        XCTAssertNotNil(theme.textColor)
    }

    func testDefaultThemeHasNonNilKeywordColor() {
        let theme = SyntaxTheme.default
        XCTAssertNotNil(theme.keywordColor)
    }

    func testDefaultThemeHasNonNilTypeColor() {
        let theme = SyntaxTheme.default
        XCTAssertNotNil(theme.typeColor)
    }

    func testDefaultThemeHasNonNilStringColor() {
        let theme = SyntaxTheme.default
        XCTAssertNotNil(theme.stringColor)
    }

    func testDefaultThemeHasNonNilNumberColor() {
        let theme = SyntaxTheme.default
        XCTAssertNotNil(theme.numberColor)
    }

    func testDefaultThemeHasNonNilCommentColor() {
        let theme = SyntaxTheme.default
        XCTAssertNotNil(theme.commentColor)
    }

    func testDefaultThemeHasNonNilFunctionColor() {
        let theme = SyntaxTheme.default
        XCTAssertNotNil(theme.functionColor)
    }

    func testDefaultThemeHasNonNilOperatorColor() {
        let theme = SyntaxTheme.default
        XCTAssertNotNil(theme.operatorColor)
    }

    func testDefaultThemeTextColorIsBlack() {
        let theme = SyntaxTheme.default
        XCTAssertEqual(theme.textColor, NSColor.black)
    }

    func testDefaultThemeFontIsMonospaced() {
        let theme = SyntaxTheme.default
        let expectedFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        XCTAssertEqual(theme.font, expectedFont)
    }

    func testCustomThemeInitialization() {
        let font = NSFont.systemFont(ofSize: 18)
        let theme = SyntaxTheme(
            font: font,
            textColor: .white,
            keywordColor: .red,
            typeColor: .blue,
            stringColor: .green,
            numberColor: .orange,
            commentColor: .gray,
            functionColor: .purple,
            operatorColor: .brown
        )
        XCTAssertEqual(theme.font, font)
        XCTAssertEqual(theme.textColor, .white)
        XCTAssertEqual(theme.keywordColor, .red)
        XCTAssertEqual(theme.typeColor, .blue)
        XCTAssertEqual(theme.stringColor, .green)
        XCTAssertEqual(theme.numberColor, .orange)
        XCTAssertEqual(theme.commentColor, .gray)
        XCTAssertEqual(theme.functionColor, .purple)
        XCTAssertEqual(theme.operatorColor, .brown)
    }
}

// MARK: - LanguageDefinition Tests

final class LanguageDefinitionTests: XCTestCase {

    func testLanguageDefinitionCanBeCreatedWithCustomValues() {
        let definition = LanguageDefinition(
            name: "TestLang",
            keywords: ["if", "else", "while"],
            types: ["Int", "String"],
            operators: ["+", "-", "="],
            commentPrefix: "//",
            multilineCommentStart: "/*",
            multilineCommentEnd: "*/",
            stringDelimiter: "\"",
            escapeCharacter: "\\",
            numberPattern: "\\d+"
        )
        XCTAssertEqual(definition.name, "TestLang")
        XCTAssertEqual(definition.keywords, ["if", "else", "while"])
        XCTAssertEqual(definition.types, ["Int", "String"])
        XCTAssertEqual(definition.operators, ["+", "-", "="])
        XCTAssertEqual(definition.commentPrefix, "//")
        XCTAssertEqual(definition.multilineCommentStart, "/*")
        XCTAssertEqual(definition.multilineCommentEnd, "*/")
        XCTAssertEqual(definition.stringDelimiter, "\"")
        XCTAssertEqual(definition.escapeCharacter, "\\")
        XCTAssertEqual(definition.numberPattern, "\\d+")
    }

    func testLanguageDefinitionWithEmptyCollections() {
        let definition = LanguageDefinition(
            name: "MinimalLang",
            keywords: [],
            types: [],
            operators: [],
            commentPrefix: "",
            multilineCommentStart: "",
            multilineCommentEnd: "",
            stringDelimiter: "",
            escapeCharacter: "",
            numberPattern: ""
        )
        XCTAssertEqual(definition.name, "MinimalLang")
        XCTAssertTrue(definition.keywords.isEmpty)
        XCTAssertTrue(definition.types.isEmpty)
        XCTAssertTrue(definition.operators.isEmpty)
        XCTAssertTrue(definition.commentPrefix.isEmpty)
    }
}

// MARK: - LanguageProvider Tests

final class LanguageProviderTests: XCTestCase {

    // MARK: - Singleton

    func testSharedInstanceIsNotNil() {
        let provider = LanguageProvider.shared
        XCTAssertNotNil(provider)
    }

    func testSharedInstanceIsSameObject() {
        let provider1 = LanguageProvider.shared
        let provider2 = LanguageProvider.shared
        XCTAssertTrue(provider1 === provider2, "shared should always return the same instance")
    }

    // MARK: - canonicalLanguageName

    func testCanonicalLanguageNameJSReturnsJavaScript() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "js"), "javascript")
    }

    func testCanonicalLanguageNamePyReturnsPython() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "py"), "python")
    }

    func testCanonicalLanguageNameMdReturnsMarkdown() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "md"), "markdown")
    }

    func testCanonicalLanguageNameShReturnsBash() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "sh"), "bash")
    }

    func testCanonicalLanguageNameTsReturnsTypeScript() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "ts"), "typescript")
    }

    func testCanonicalLanguageNameRbReturnsRuby() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "rb"), "ruby")
    }

    func testCanonicalLanguageNameCppReturnsCPlusPlus() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "cpp"), "c++")
    }

    func testCanonicalLanguageNameHReturnsC() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "h"), "c")
    }

    func testCanonicalLanguageNameYmlReturnsYaml() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "yml"), "yaml")
    }

    func testCanonicalLanguageNameZshReturnsBash() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "zsh"), "bash")
    }

    func testCanonicalLanguageNameShellReturnsBash() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "shell"), "bash")
    }

    func testCanonicalLanguageNameBashReturnsBash() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "bash"), "bash")
    }

    func testCanonicalLanguageNameNilReturnsNil() {
        let provider = LanguageProvider.shared
        XCTAssertNil(provider.canonicalLanguageName(from: nil))
    }

    func testCanonicalLanguageNameUnknownReturnsLowercased() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "Rust"), "rust")
    }

    func testCanonicalLanguageNameUnknownPreservesValue() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "kotlin"), "kotlin")
    }

    func testCanonicalLanguageNameIsCaseInsensitive() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "JS"), "javascript")
        XCTAssertEqual(provider.canonicalLanguageName(from: "Py"), "python")
    }

    // MARK: - detectLanguage from filename

    func testDetectLanguageFromSwiftFile() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "test.swift"), "swift")
    }

    func testDetectLanguageFromPythonFile() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "test.py"), "python")
    }

    func testDetectLanguageFromJavaScriptFile() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "test.js"), "javascript")
    }

    func testDetectLanguageFromTypeScriptFile() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "test.ts"), "typescript")
    }

    func testDetectLanguageFromMarkdownFile() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "README.md"), "markdown")
    }

    func testDetectLanguageFromShellFile() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "script.sh"), "bash")
    }

    func testDetectLanguageFromCppFile() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "main.cpp"), "c++")
    }

    func testDetectLanguageFromHeaderFile() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "header.h"), "c")
    }

    func testDetectLanguageFromYmlFile() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "config.yml"), "yaml")
    }

    func testDetectLanguageFromRubyFile() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "app.rb"), "ruby")
    }

    func testDetectLanguageFromFileWithPath() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.detectLanguage(from: "/path/to/file.swift"), "swift")
    }

    func testDetectLanguageFromFileWithNoExtension() {
        let provider = LanguageProvider.shared
        // A file with no extension yields an empty string for the extension
        let result = provider.detectLanguage(from: "Makefile")
        // canonicalLanguageName with empty string will return ""
        XCTAssertEqual(result, "")
    }

    // MARK: - detectLanguage from content

    func testDetectLanguageFromContentImportSwift() {
        let provider = LanguageProvider.shared
        let content = "import Swift\nlet x = 42"
        XCTAssertEqual(provider.detectLanguage(fromContent: content), "swift")
    }

    func testDetectLanguageFromContentSwiftFuncAndVar() {
        let provider = LanguageProvider.shared
        let content = "func hello() {\n    var x = 10\n}"
        XCTAssertEqual(provider.detectLanguage(fromContent: content), "swift")
    }

    func testDetectLanguageFromContentPythonDef() {
        let provider = LanguageProvider.shared
        let content = "def foo():\n    return 42"
        XCTAssertEqual(provider.detectLanguage(fromContent: content), "python")
    }

    func testDetectLanguageFromContentPHP() {
        let provider = LanguageProvider.shared
        let content = "<?php\necho 'Hello World';"
        XCTAssertEqual(provider.detectLanguage(fromContent: content), "php")
    }

    func testDetectLanguageFromContentGoPackageMain() {
        let provider = LanguageProvider.shared
        let content = "package main\n\nimport \"fmt\"\n\nfunc main() {\n    fmt.Println(\"hello\")\n}"
        XCTAssertEqual(provider.detectLanguage(fromContent: content), "go")
    }

    func testDetectLanguageFromContentCInclude() {
        let provider = LanguageProvider.shared
        let content = "#include <stdio.h>\nint main() { return 0; }"
        XCTAssertEqual(provider.detectLanguage(fromContent: content), "c")
    }

    func testDetectLanguageFromContentJavaScriptFunction() {
        let provider = LanguageProvider.shared
        let content = "function greet(name) {\n    return 'Hello ' + name;\n}"
        XCTAssertEqual(provider.detectLanguage(fromContent: content), "javascript")
    }

    func testDetectLanguageFromContentJavaScriptConst() {
        let provider = LanguageProvider.shared
        let content = "const x = 42;\nconsole.log(x);"
        XCTAssertEqual(provider.detectLanguage(fromContent: content), "javascript")
    }

    func testDetectLanguageFromContentUnrecognizable() {
        let provider = LanguageProvider.shared
        let content = "just some random plain text with no language hints"
        XCTAssertNil(provider.detectLanguage(fromContent: content))
    }

    func testDetectLanguageFromEmptyContent() {
        let provider = LanguageProvider.shared
        XCTAssertNil(provider.detectLanguage(fromContent: ""))
    }
}

#endif
