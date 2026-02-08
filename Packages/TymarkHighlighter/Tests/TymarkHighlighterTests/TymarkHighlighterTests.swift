import XCTest
@testable import TymarkHighlighter

final class TymarkHighlighterTests: XCTestCase {
    func testHighlighterInitialization() {
        let highlighter = SyntaxHighlighter()
        XCTAssertFalse(highlighter.supportedLanguages().isEmpty)
    }

    func testLanguageDetection() {
        let provider = LanguageProvider.shared
        XCTAssertEqual(provider.canonicalLanguageName(from: "js"), "javascript")
    }
}
