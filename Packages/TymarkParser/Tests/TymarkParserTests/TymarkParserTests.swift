import XCTest
@testable import TymarkParser

final class TymarkParserTests: XCTestCase {

    var parser: MarkdownParser!

    override func setUp() {
        super.setUp()
        parser = MarkdownParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Basic Parsing Tests

    func testParseEmptyString() {
        let document = parser.parse("")
        XCTAssertEqual(document.root.type, .document)
        XCTAssertTrue(document.root.children.isEmpty)
    }

    func testParseHeading() {
        let document = parser.parse("# Heading 1")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 1))
    }

    func testParseMultipleHeadings() {
        let markdown = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 3)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 1))
        XCTAssertEqual(document.root.children[1].type, .heading(level: 2))
        XCTAssertEqual(document.root.children[2].type, .heading(level: 3))
    }

    func testParseParagraph() {
        let document = parser.parse("This is a paragraph.")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .paragraph)
    }

    func testParseEmphasis() {
        let document = parser.parse("*italic* and _also italic_")
        let paragraph = document.root.children[0]
        let emphasisNodes = paragraph.children.filter {
            if case .emphasis = $0.type { return true }
            return false
        }
        XCTAssertEqual(emphasisNodes.count, 2)
    }

    func testParseStrong() {
        let document = parser.parse("**bold** and __also bold__")
        let paragraph = document.root.children[0]
        let strongNodes = paragraph.children.filter {
            if case .strong = $0.type { return true }
            return false
        }
        XCTAssertEqual(strongNodes.count, 2)
    }

    func testParseCode() {
        let document = parser.parse("`inline code`")
        let paragraph = document.root.children[0]
        let codeNodes = paragraph.children.filter {
            if case .inlineCode = $0.type { return true }
            return false
        }
        XCTAssertEqual(codeNodes.count, 1)
        XCTAssertEqual(codeNodes[0].content, "inline code")
    }

    func testParseCodeBlock() {
        let markdown = """
        ```swift
        let x = 5
        ```
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .codeBlock(language: "swift"))
    }

    func testParseBlockquote() {
        let document = parser.parse("> This is a quote")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .blockquote)
    }

    func testParseList() {
        let markdown = """
        - Item 1
        - Item 2
        - Item 3
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .list(ordered: false))
    }

    func testParseOrderedList() {
        let markdown = """
        1. First
        2. Second
        3. Third
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .list(ordered: true))
    }

    func testParseLink() {
        let document = parser.parse("[Link text](https://example.com)")
        let paragraph = document.root.children[0]
        let linkNodes = paragraph.children.filter {
            if case .link = $0.type { return true }
            return false
        }
        XCTAssertEqual(linkNodes.count, 1)
    }

    // MARK: - Incremental Parser Tests

    func testIncrementalParser() {
        let incrementalParser = IncrementalParser()
        let initialSource = "# Hello\n\nWorld"
        let document = incrementalParser.parse(initialSource)

        XCTAssertEqual(document.root.children.count, 2)
    }

    // MARK: - AST Diff Tests

    func testASTDiff() {
        let diff = ASTDiff()
        let oldDoc = parser.parse("# Old")
        let newDoc = parser.parse("# New")

        let results = diff.diff(oldDocument: oldDoc, newDocument: newDoc)
        XCTAssertFalse(results.isEmpty)
    }
}
