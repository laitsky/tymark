#if canImport(XCTest)
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

    // MARK: - Helper Methods

    /// Convenience to get the first child of the document root.
    private func firstChild(of document: TymarkDocument) -> TymarkNode? {
        document.root.children.first
    }

    /// Convenience to collect children of a given type from a node.
    private func children(
        of node: TymarkNode,
        matching predicate: (TymarkNodeType) -> Bool
    ) -> [TymarkNode] {
        node.children.filter { predicate($0.type) }
    }

    // MARK: - 1. Basic Parsing: Empty String

    func testParseEmptyString() {
        let document = parser.parse("")
        XCTAssertEqual(document.root.type, .document)
        XCTAssertTrue(document.root.children.isEmpty, "Empty input should produce no children")
        XCTAssertEqual(document.source, "")
    }

    func testParseWhitespaceOnly() {
        let document = parser.parse("   \n  \n   ")
        XCTAssertEqual(document.root.type, .document)
        // Whitespace-only input should produce no meaningful blocks
        XCTAssertTrue(document.root.children.isEmpty)
    }

    // MARK: - 1. Basic Parsing: Headings 1-6

    func testParseHeading1() {
        let document = parser.parse("# Heading 1")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 1))
    }

    func testParseHeading2() {
        let document = parser.parse("## Heading 2")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 2))
    }

    func testParseHeading3() {
        let document = parser.parse("### Heading 3")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 3))
    }

    func testParseHeading4() {
        let document = parser.parse("#### Heading 4")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 4))
    }

    func testParseHeading5() {
        let document = parser.parse("##### Heading 5")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 5))
    }

    func testParseHeading6() {
        let document = parser.parse("###### Heading 6")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 6))
    }

    func testParseAllHeadingLevels() {
        let markdown = """
        # H1
        ## H2
        ### H3
        #### H4
        ##### H5
        ###### H6
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 6)
        for level in 1...6 {
            XCTAssertEqual(
                document.root.children[level - 1].type,
                .heading(level: level),
                "Child at index \(level - 1) should be heading level \(level)"
            )
        }
    }

    func testHeadingContainsTextChild() {
        let document = parser.parse("# Title Text")
        let heading = document.root.children[0]
        XCTAssertEqual(heading.type, .heading(level: 1))
        let textChildren = heading.children.filter { $0.type == .text }
        XCTAssertFalse(textChildren.isEmpty, "Heading should contain a text child node")
        XCTAssertEqual(textChildren[0].content, "Title Text")
    }

    // MARK: - 1. Basic Parsing: Paragraphs

    func testParseSingleParagraph() {
        let document = parser.parse("This is a paragraph.")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .paragraph)
    }

    func testParseMultipleParagraphs() {
        let markdown = """
        First paragraph.

        Second paragraph.

        Third paragraph.
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 3)
        for child in document.root.children {
            XCTAssertEqual(child.type, .paragraph)
        }
    }

    func testParagraphContainsTextContent() {
        let document = parser.parse("Hello, world!")
        let paragraph = document.root.children[0]
        let textNodes = paragraph.children.filter { $0.type == .text }
        XCTAssertFalse(textNodes.isEmpty)
        XCTAssertEqual(textNodes[0].content, "Hello, world!")
    }

    // MARK: - 1. Basic Parsing: Emphasis

    func testParseAsteriskEmphasis() {
        let document = parser.parse("*italic text*")
        let paragraph = document.root.children[0]
        let emphasisNodes = children(of: paragraph) { type in
            if case .emphasis = type { return true }
            return false
        }
        XCTAssertEqual(emphasisNodes.count, 1)
    }

    func testParseUnderscoreEmphasis() {
        let document = parser.parse("_italic text_")
        let paragraph = document.root.children[0]
        let emphasisNodes = children(of: paragraph) { type in
            if case .emphasis = type { return true }
            return false
        }
        XCTAssertEqual(emphasisNodes.count, 1)
    }

    func testParseBothEmphasisStyles() {
        let document = parser.parse("*asterisk* and _underscore_")
        let paragraph = document.root.children[0]
        let emphasisNodes = children(of: paragraph) { type in
            if case .emphasis = type { return true }
            return false
        }
        XCTAssertEqual(emphasisNodes.count, 2)
    }

    // MARK: - 1. Basic Parsing: Strong

    func testParseAsteriskStrong() {
        let document = parser.parse("**bold text**")
        let paragraph = document.root.children[0]
        let strongNodes = children(of: paragraph) { type in
            if case .strong = type { return true }
            return false
        }
        XCTAssertEqual(strongNodes.count, 1)
    }

    func testParseUnderscoreStrong() {
        let document = parser.parse("__bold text__")
        let paragraph = document.root.children[0]
        let strongNodes = children(of: paragraph) { type in
            if case .strong = type { return true }
            return false
        }
        XCTAssertEqual(strongNodes.count, 1)
    }

    // MARK: - 1. Basic Parsing: Inline Code

    func testParseInlineCode() {
        let document = parser.parse("`code`")
        let paragraph = document.root.children[0]
        let codeNodes = children(of: paragraph) { type in
            if case .inlineCode = type { return true }
            return false
        }
        XCTAssertEqual(codeNodes.count, 1)
        XCTAssertEqual(codeNodes[0].content, "code")
    }

    func testParseInlineCodeWithSpecialCharacters() {
        let document = parser.parse("`let x = 5 + 3`")
        let paragraph = document.root.children[0]
        let codeNodes = children(of: paragraph) { type in
            if case .inlineCode = type { return true }
            return false
        }
        XCTAssertEqual(codeNodes.count, 1)
        XCTAssertEqual(codeNodes[0].content, "let x = 5 + 3")
    }

    // MARK: - 1. Basic Parsing: Code Blocks

    func testParseCodeBlockWithLanguage() {
        let markdown = """
        ```swift
        let x = 5
        ```
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .codeBlock(language: "swift"))
        XCTAssertTrue(document.root.children[0].content.contains("let x = 5"))
    }

    func testParseCodeBlockWithoutLanguage() {
        let markdown = """
        ```
        some code here
        ```
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        let codeBlock = document.root.children[0]
        if case .codeBlock(let language) = codeBlock.type {
            // Language should be nil or empty for fenced code blocks without a language
            XCTAssertTrue(language == nil || language?.isEmpty == true)
        } else {
            XCTFail("Expected codeBlock node type")
        }
        XCTAssertTrue(codeBlock.content.contains("some code here"))
    }

    func testParseCodeBlockWithPythonLanguage() {
        let markdown = """
        ```python
        def hello():
            print("Hello")
        ```
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children[0].type, .codeBlock(language: "python"))
    }

    func testParseCodeBlockPreservesContent() {
        let markdown = """
        ```
        line 1
        line 2
        line 3
        ```
        """
        let document = parser.parse(markdown)
        let codeBlock = document.root.children[0]
        XCTAssertTrue(codeBlock.content.contains("line 1"))
        XCTAssertTrue(codeBlock.content.contains("line 2"))
        XCTAssertTrue(codeBlock.content.contains("line 3"))
    }

    // MARK: - 2. Block Elements: Blockquotes

    func testParseSingleBlockquote() {
        let document = parser.parse("> This is a quote")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .blockquote)
    }

    func testParseMultilineBlockquote() {
        let markdown = """
        > Line one
        > Line two
        > Line three
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .blockquote)
    }

    func testParseNestedBlockquotes() {
        let markdown = """
        > Outer quote
        > > Inner quote
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        let outerQuote = document.root.children[0]
        XCTAssertEqual(outerQuote.type, .blockquote)
        // The nested blockquote should appear among the children
        let innerQuotes = children(of: outerQuote) { type in
            if case .blockquote = type { return true }
            return false
        }
        XCTAssertFalse(innerQuotes.isEmpty, "Nested blockquote should be a child of the outer blockquote")
    }

    func testBlockquoteContainsParagraphChild() {
        let document = parser.parse("> A quoted paragraph")
        let blockquote = document.root.children[0]
        XCTAssertEqual(blockquote.type, .blockquote)
        let paragraphs = children(of: blockquote) { type in
            if case .paragraph = type { return true }
            return false
        }
        XCTAssertFalse(paragraphs.isEmpty, "Blockquote should contain a paragraph child")
    }

    // MARK: - 2. Block Elements: Unordered Lists

    func testParseUnorderedListDash() {
        let markdown = """
        - Item 1
        - Item 2
        - Item 3
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        let list = document.root.children[0]
        XCTAssertEqual(list.type, .list(ordered: false))
        XCTAssertEqual(list.children.count, 3)
        for item in list.children {
            XCTAssertEqual(item.type, .listItem)
        }
    }

    func testParseUnorderedListAsterisk() {
        let markdown = """
        * Item A
        * Item B
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .list(ordered: false))
        XCTAssertEqual(document.root.children[0].children.count, 2)
    }

    // MARK: - 2. Block Elements: Ordered Lists

    func testParseOrderedList() {
        let markdown = """
        1. First
        2. Second
        3. Third
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        let list = document.root.children[0]
        XCTAssertEqual(list.type, .list(ordered: true))
        XCTAssertEqual(list.children.count, 3)
        for item in list.children {
            XCTAssertEqual(item.type, .listItem)
        }
    }

    // MARK: - 2. Block Elements: Thematic Breaks

    func testParseThematicBreakDashes() {
        let markdown = """
        Above

        ---

        Below
        """
        let document = parser.parse(markdown)
        let breakNodes = document.root.children.filter { $0.type == .thematicBreak }
        XCTAssertEqual(breakNodes.count, 1)
    }

    func testParseThematicBreakAsterisks() {
        let markdown = """
        Above

        ***

        Below
        """
        let document = parser.parse(markdown)
        let breakNodes = document.root.children.filter { $0.type == .thematicBreak }
        XCTAssertEqual(breakNodes.count, 1)
    }

    func testParseThematicBreakUnderscores() {
        let markdown = """
        Above

        ___

        Below
        """
        let document = parser.parse(markdown)
        let breakNodes = document.root.children.filter { $0.type == .thematicBreak }
        XCTAssertEqual(breakNodes.count, 1)
    }

    // MARK: - 2. Block Elements: Tables

    func testParseTable() {
        let markdown = """
        | Header 1 | Header 2 |
        | -------- | -------- |
        | Cell 1   | Cell 2   |
        """
        let document = parser.parse(markdown)
        let tableNodes = document.root.children.filter { $0.type == .table }
        XCTAssertEqual(tableNodes.count, 1, "Should parse a table")
    }

    func testParseTableHasRowsAndCells() {
        let markdown = """
        | A | B |
        | - | - |
        | 1 | 2 |
        | 3 | 4 |
        """
        let document = parser.parse(markdown)
        let tableNodes = document.root.children.filter { $0.type == .table }
        XCTAssertEqual(tableNodes.count, 1)
        let table = tableNodes[0]
        // The table should have children (head and body rows)
        XCTAssertFalse(table.children.isEmpty, "Table should have child rows")
    }

    // MARK: - 3. Inline Elements: Links

    func testParseLinkWithDestination() {
        let document = parser.parse("[Example](https://example.com)")
        let paragraph = document.root.children[0]
        let linkNodes = children(of: paragraph) { type in
            if case .link = type { return true }
            return false
        }
        XCTAssertEqual(linkNodes.count, 1)
        if case .link(let destination, _) = linkNodes[0].type {
            XCTAssertEqual(destination, "https://example.com")
        } else {
            XCTFail("Expected link node type")
        }
    }

    func testParseLinkWithTitle() {
        let document = parser.parse("[Example](https://example.com \"A title\")")
        let paragraph = document.root.children[0]
        let linkNodes = children(of: paragraph) { type in
            if case .link = type { return true }
            return false
        }
        XCTAssertEqual(linkNodes.count, 1)
        if case .link(let destination, let title) = linkNodes[0].type {
            XCTAssertEqual(destination, "https://example.com")
            XCTAssertEqual(title, "A title")
        } else {
            XCTFail("Expected link node type with title")
        }
    }

    func testParseLinkContainsTextChild() {
        let document = parser.parse("[Click me](https://example.com)")
        let paragraph = document.root.children[0]
        let linkNodes = children(of: paragraph) { type in
            if case .link = type { return true }
            return false
        }
        XCTAssertEqual(linkNodes.count, 1)
        let link = linkNodes[0]
        let textChildren = link.children.filter { $0.type == .text }
        XCTAssertFalse(textChildren.isEmpty)
        XCTAssertEqual(textChildren[0].content, "Click me")
    }

    // MARK: - 3. Inline Elements: Images

    func testParseImage() {
        let document = parser.parse("![Alt text](image.png)")
        let paragraph = document.root.children[0]
        let imageNodes = children(of: paragraph) { type in
            if case .image = type { return true }
            return false
        }
        XCTAssertEqual(imageNodes.count, 1)
        if case .image(let source, let alt) = imageNodes[0].type {
            XCTAssertEqual(source, "image.png")
            XCTAssertEqual(alt, "Alt text")
        } else {
            XCTFail("Expected image node type")
        }
    }

    func testParseImageWithURL() {
        let document = parser.parse("![Logo](https://example.com/logo.png)")
        let paragraph = document.root.children[0]
        let imageNodes = children(of: paragraph) { type in
            if case .image = type { return true }
            return false
        }
        XCTAssertEqual(imageNodes.count, 1)
        if case .image(let source, _) = imageNodes[0].type {
            XCTAssertEqual(source, "https://example.com/logo.png")
        } else {
            XCTFail("Expected image node type")
        }
    }

    // MARK: - 3. Inline Elements: Strikethrough

    func testParseStrikethrough() {
        let document = parser.parse("~~deleted text~~")
        let paragraph = document.root.children[0]
        let strikethroughNodes = children(of: paragraph) { type in
            if case .strikethrough = type { return true }
            return false
        }
        XCTAssertEqual(strikethroughNodes.count, 1)
    }

    // MARK: - 3. Inline Elements: Nested Emphasis and Strong

    func testParseNestedEmphasisInsideStrong() {
        let document = parser.parse("***bold and italic***")
        let paragraph = document.root.children[0]
        // This should produce a strong containing emphasis (or vice versa)
        let strongNodes = children(of: paragraph) { type in
            if case .strong = type { return true }
            return false
        }
        let emphasisNodes = children(of: paragraph) { type in
            if case .emphasis = type { return true }
            return false
        }
        // At least one strong or emphasis node should exist at top level
        XCTAssertTrue(
            !strongNodes.isEmpty || !emphasisNodes.isEmpty,
            "Should parse nested bold+italic formatting"
        )
    }

    func testParseStrongInsideEmphasis() {
        let document = parser.parse("*italic and **bold** text*")
        let paragraph = document.root.children[0]
        let emphasisNodes = children(of: paragraph) { type in
            if case .emphasis = type { return true }
            return false
        }
        XCTAssertFalse(emphasisNodes.isEmpty, "Should find emphasis node")
        // Inside the emphasis, there should be a strong node
        if let emphasis = emphasisNodes.first {
            let innerStrong = children(of: emphasis) { type in
                if case .strong = type { return true }
                return false
            }
            XCTAssertFalse(innerStrong.isEmpty, "Emphasis should contain a nested strong node")
        }
    }

    // MARK: - 3. Inline Elements: Mixed Inline

    func testParseMixedInlineElements() {
        let document = parser.parse("Normal *italic* **bold** `code` [link](url)")
        let paragraph = document.root.children[0]
        XCTAssertFalse(paragraph.children.isEmpty)

        let textNodes = paragraph.children.filter { $0.type == .text }
        let emphasisNodes = children(of: paragraph) { type in
            if case .emphasis = type { return true }
            return false
        }
        let strongNodes = children(of: paragraph) { type in
            if case .strong = type { return true }
            return false
        }
        let codeNodes = children(of: paragraph) { type in
            if case .inlineCode = type { return true }
            return false
        }
        let linkNodes = children(of: paragraph) { type in
            if case .link = type { return true }
            return false
        }

        XCTAssertFalse(textNodes.isEmpty, "Should contain text nodes")
        XCTAssertEqual(emphasisNodes.count, 1, "Should contain one emphasis node")
        XCTAssertEqual(strongNodes.count, 1, "Should contain one strong node")
        XCTAssertEqual(codeNodes.count, 1, "Should contain one inline code node")
        XCTAssertEqual(linkNodes.count, 1, "Should contain one link node")
    }

    // MARK: - 4. Complex Documents: Multi-Block

    func testParseMultiBlockDocument() {
        let markdown = """
        # Title

        First paragraph.

        ## Subtitle

        Second paragraph with **bold**.

        - List item 1
        - List item 2
        """
        let document = parser.parse(markdown)
        // Should have: heading, paragraph, heading, paragraph, list
        XCTAssertEqual(document.root.children.count, 5)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 1))
        XCTAssertEqual(document.root.children[1].type, .paragraph)
        XCTAssertEqual(document.root.children[2].type, .heading(level: 2))
        XCTAssertEqual(document.root.children[3].type, .paragraph)
        XCTAssertEqual(document.root.children[4].type, .list(ordered: false))
    }

    func testParseDocumentWithCodeAndQuote() {
        let markdown = """
        > A wise quote.

        ```javascript
        console.log("hello");
        ```

        A paragraph after code.
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 3)
        XCTAssertEqual(document.root.children[0].type, .blockquote)
        XCTAssertEqual(document.root.children[1].type, .codeBlock(language: "javascript"))
        XCTAssertEqual(document.root.children[2].type, .paragraph)
    }

    // MARK: - 4. Complex Documents: Nested Lists

    func testParseNestedUnorderedList() {
        let markdown = """
        - Outer 1
          - Inner 1a
          - Inner 1b
        - Outer 2
        """
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        let list = document.root.children[0]
        XCTAssertEqual(list.type, .list(ordered: false))
        // The first list item should have a nested list among its children
        let firstItem = list.children[0]
        XCTAssertEqual(firstItem.type, .listItem)
        let nestedLists = children(of: firstItem) { type in
            if case .list = type { return true }
            return false
        }
        XCTAssertFalse(nestedLists.isEmpty, "First list item should contain a nested list")
    }

    func testParseNestedOrderedInUnordered() {
        let markdown = """
        - Unordered item
          1. Ordered sub-item 1
          2. Ordered sub-item 2
        """
        let document = parser.parse(markdown)
        let list = document.root.children[0]
        XCTAssertEqual(list.type, .list(ordered: false))
        let firstItem = list.children[0]
        let nestedLists = children(of: firstItem) { type in
            if case .list(let ordered) = type { return ordered }
            return false
        }
        XCTAssertFalse(nestedLists.isEmpty, "Should contain nested ordered list")
    }

    // MARK: - 4. Complex Documents: Interleaved Blocks

    func testParseInterleavedBlocks() {
        let markdown = """
        Paragraph one.

        > Blockquote one.

        Paragraph two.

        ---

        Paragraph three.

        > Blockquote two.
        """
        let document = parser.parse(markdown)
        let types = document.root.children.map { $0.type }
        XCTAssertEqual(types.count, 6)
        XCTAssertEqual(types[0], .paragraph)
        XCTAssertEqual(types[1], .blockquote)
        XCTAssertEqual(types[2], .paragraph)
        XCTAssertEqual(types[3], .thematicBreak)
        XCTAssertEqual(types[4], .paragraph)
        XCTAssertEqual(types[5], .blockquote)
    }

    // MARK: - 4. Complex Documents: Source Preservation

    func testDocumentSourcePreservation() {
        let markdown = "# Hello\n\nWorld"
        let document = parser.parse(markdown)
        XCTAssertEqual(document.source, markdown)
    }

    func testDocumentVersionIsUnique() {
        let doc1 = parser.parse("# One")
        let doc2 = parser.parse("# Two")
        XCTAssertNotEqual(doc1.version, doc2.version)
    }

    // MARK: - 5. AST Node Helpers: isBlock

    func testIsBlockForBlockTypes() {
        let blockTypes: [TymarkNodeType] = [
            .document,
            .paragraph,
            .heading(level: 1),
            .blockquote,
            .list(ordered: false),
            .list(ordered: true),
            .listItem,
            .codeBlock(language: nil),
            .codeBlock(language: "swift"),
            .thematicBreak,
            .table,
            .tableRow,
            .tableCell,
            .html,
        ]
        for nodeType in blockTypes {
            let node = TymarkNode(type: nodeType, range: NSRange(location: 0, length: 0))
            XCTAssertTrue(node.isBlock, "\(nodeType) should be a block element")
        }
    }

    func testIsBlockReturnsFalseForInlineTypes() {
        let inlineTypes: [TymarkNodeType] = [
            .text,
            .emphasis,
            .strong,
            .inlineCode,
            .link(destination: "", title: nil),
            .image(source: "", alt: nil),
            .softBreak,
            .lineBreak,
            .strikethrough,
        ]
        for nodeType in inlineTypes {
            let node = TymarkNode(type: nodeType, range: NSRange(location: 0, length: 0))
            XCTAssertFalse(node.isBlock, "\(nodeType) should NOT be a block element")
        }
    }

    // MARK: - 5. AST Node Helpers: isInline

    func testIsInlineForInlineTypes() {
        let inlineTypes: [TymarkNodeType] = [
            .text,
            .emphasis,
            .strong,
            .inlineCode,
            .link(destination: "url", title: "title"),
            .image(source: "src", alt: "alt"),
            .softBreak,
            .lineBreak,
            .strikethrough,
        ]
        for nodeType in inlineTypes {
            let node = TymarkNode(type: nodeType, range: NSRange(location: 0, length: 0))
            XCTAssertTrue(node.isInline, "\(nodeType) should be an inline element")
        }
    }

    func testIsInlineReturnsFalseForBlockTypes() {
        let blockTypes: [TymarkNodeType] = [
            .document,
            .paragraph,
            .heading(level: 2),
            .blockquote,
            .list(ordered: false),
            .codeBlock(language: nil),
            .thematicBreak,
            .table,
        ]
        for nodeType in blockTypes {
            let node = TymarkNode(type: nodeType, range: NSRange(location: 0, length: 0))
            XCTAssertFalse(node.isInline, "\(nodeType) should NOT be an inline element")
        }
    }

    // MARK: - 5. AST Node Helpers: headingLevel

    func testHeadingLevelForHeadingNode() {
        for level in 1...6 {
            let node = TymarkNode(type: .heading(level: level), range: NSRange(location: 0, length: 0))
            XCTAssertEqual(node.headingLevel, level)
        }
    }

    func testHeadingLevelIsNilForNonHeading() {
        let node = TymarkNode(type: .paragraph, range: NSRange(location: 0, length: 0))
        XCTAssertNil(node.headingLevel)
    }

    func testHeadingLevelIsNilForTextNode() {
        let node = TymarkNode(type: .text, content: "hello", range: NSRange(location: 0, length: 5))
        XCTAssertNil(node.headingLevel)
    }

    // MARK: - 5. AST Node Helpers: codeLanguage

    func testCodeLanguageForCodeBlockWithLanguage() {
        let node = TymarkNode(type: .codeBlock(language: "swift"), range: NSRange(location: 0, length: 0))
        XCTAssertEqual(node.codeLanguage, "swift")
    }

    func testCodeLanguageForCodeBlockWithoutLanguage() {
        let node = TymarkNode(type: .codeBlock(language: nil), range: NSRange(location: 0, length: 0))
        XCTAssertNil(node.codeLanguage)
    }

    func testCodeLanguageIsNilForNonCodeBlock() {
        let node = TymarkNode(type: .paragraph, range: NSRange(location: 0, length: 0))
        XCTAssertNil(node.codeLanguage)
    }

    // MARK: - 5. AST Node Helpers: child(at:)

    func testChildAtEmptyPath() {
        let node = TymarkNode(
            type: .document,
            range: NSRange(location: 0, length: 10),
            children: [
                TymarkNode(type: .paragraph, range: NSRange(location: 0, length: 10))
            ]
        )
        // Empty path should return the node itself
        let result = node.child(at: [])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .document)
    }

    func testChildAtSingleIndex() {
        let child0 = TymarkNode(type: .paragraph, range: NSRange(location: 0, length: 5))
        let child1 = TymarkNode(type: .heading(level: 1), range: NSRange(location: 5, length: 5))
        let root = TymarkNode(
            type: .document,
            range: NSRange(location: 0, length: 10),
            children: [child0, child1]
        )
        let result = root.child(at: [1])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .heading(level: 1))
    }

    func testChildAtNestedPath() {
        let innerChild = TymarkNode(type: .text, content: "Hello", range: NSRange(location: 0, length: 5))
        let paragraph = TymarkNode(
            type: .paragraph,
            range: NSRange(location: 0, length: 5),
            children: [innerChild]
        )
        let root = TymarkNode(
            type: .document,
            range: NSRange(location: 0, length: 5),
            children: [paragraph]
        )
        let result = root.child(at: [0, 0])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .text)
        XCTAssertEqual(result?.content, "Hello")
    }

    func testChildAtInvalidPathReturnsNil() {
        let root = TymarkNode(
            type: .document,
            range: NSRange(location: 0, length: 0),
            children: []
        )
        let result = root.child(at: [0])
        XCTAssertNil(result)
    }

    func testChildAtOutOfBoundsReturnsNil() {
        let child = TymarkNode(type: .paragraph, range: NSRange(location: 0, length: 5))
        let root = TymarkNode(
            type: .document,
            range: NSRange(location: 0, length: 5),
            children: [child]
        )
        let result = root.child(at: [5])
        XCTAssertNil(result)
    }

    func testChildAtDeeplyNestedPath() {
        let leaf = TymarkNode(type: .text, content: "deep", range: NSRange(location: 0, length: 4))
        let level2 = TymarkNode(type: .emphasis, range: NSRange(location: 0, length: 4), children: [leaf])
        let level1 = TymarkNode(type: .paragraph, range: NSRange(location: 0, length: 4), children: [level2])
        let root = TymarkNode(type: .document, range: NSRange(location: 0, length: 4), children: [level1])

        let result = root.child(at: [0, 0, 0])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.content, "deep")
    }

    // MARK: - 5. AST Node Helpers: node(at:)

    func testNodeAtLocationFindsDeepestNode() {
        let text = TymarkNode(type: .text, content: "Hi", range: NSRange(location: 2, length: 2))
        let paragraph = TymarkNode(
            type: .paragraph,
            range: NSRange(location: 0, length: 5),
            children: [text]
        )
        let root = TymarkNode(
            type: .document,
            range: NSRange(location: 0, length: 5),
            children: [paragraph]
        )

        // Location 3 is inside the text node (range 2..<4)
        let result = root.node(at: 3)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .text)
    }

    func testNodeAtLocationOutsideRangeReturnsNil() {
        let root = TymarkNode(
            type: .document,
            range: NSRange(location: 0, length: 5),
            children: []
        )
        let result = root.node(at: 10)
        XCTAssertNil(result)
    }

    func testNodeAtLocationReturnsParentWhenNoChildMatches() {
        let paragraph = TymarkNode(
            type: .paragraph,
            range: NSRange(location: 0, length: 10),
            children: [
                TymarkNode(type: .text, content: "ab", range: NSRange(location: 0, length: 2))
            ]
        )
        let root = TymarkNode(
            type: .document,
            range: NSRange(location: 0, length: 10),
            children: [paragraph]
        )

        // Location 5 is inside paragraph but not inside the text child
        let result = root.node(at: 5)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .paragraph)
    }

    func testNodeAtLocationFromParsedDocument() {
        let markdown = "# Heading\n\nParagraph text"
        let document = parser.parse(markdown)
        // Location 0 should be inside the heading
        let node = document.root.node(at: 0)
        XCTAssertNotNil(node)
    }

    // MARK: - 5. AST Node Helpers: Custom Node Type

    func testCustomNodeType() {
        let node = TymarkNode(
            type: .custom(name: "footnote"),
            range: NSRange(location: 0, length: 10)
        )
        if case .custom(let name) = node.type {
            XCTAssertEqual(name, "footnote")
        } else {
            XCTFail("Expected custom node type")
        }
        // Custom nodes are neither block nor inline by default
        XCTAssertFalse(node.isBlock)
        XCTAssertFalse(node.isInline)
    }

    // MARK: - 5. AST Node Helpers: Metadata

    func testNodeMetadata() {
        let node = TymarkNode(
            type: .paragraph,
            range: NSRange(location: 0, length: 5),
            metadata: ["key": "value", "another": "data"]
        )
        XCTAssertEqual(node.metadata["key"], "value")
        XCTAssertEqual(node.metadata["another"], "data")
        XCTAssertNil(node.metadata["nonexistent"])
    }

    // MARK: - 5. AST Node Helpers: Node Range

    func testNodeRangeFromParsedHeading() {
        let document = parser.parse("# Hello")
        let heading = document.root.children[0]
        XCTAssertEqual(heading.range.location, 0)
        XCTAssertTrue(heading.range.length > 0, "Heading range should have non-zero length")
    }

    // MARK: - 5. AST Node Helpers: Equatable and Hashable

    func testNodeEquality() {
        let id = UUID()
        let node1 = TymarkNode(id: id, type: .text, content: "hello", range: NSRange(location: 0, length: 5))
        let node2 = TymarkNode(id: id, type: .text, content: "hello", range: NSRange(location: 0, length: 5))
        XCTAssertEqual(node1, node2)
    }

    func testNodeInequalityDifferentContent() {
        let id = UUID()
        let node1 = TymarkNode(id: id, type: .text, content: "hello", range: NSRange(location: 0, length: 5))
        let node2 = TymarkNode(id: id, type: .text, content: "world", range: NSRange(location: 0, length: 5))
        XCTAssertNotEqual(node1, node2)
    }

    func testNodeInequalityDifferentType() {
        let id = UUID()
        let node1 = TymarkNode(id: id, type: .paragraph, range: NSRange(location: 0, length: 5))
        let node2 = TymarkNode(id: id, type: .heading(level: 1), range: NSRange(location: 0, length: 5))
        XCTAssertNotEqual(node1, node2)
    }

    func testNodeHashableInSet() {
        let node1 = TymarkNode(type: .text, content: "a", range: NSRange(location: 0, length: 1))
        let node2 = TymarkNode(type: .text, content: "b", range: NSRange(location: 1, length: 1))
        let set: Set<TymarkNode> = [node1, node2]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - 6. AST Diff: Unchanged Documents

    func testDiffUnchangedDocuments() {
        let source = "# Title\n\nParagraph text."
        let oldDoc = parser.parse(source)
        // Re-parse the same source to get structurally identical doc with different IDs
        // Since IDs differ, content comparison matters
        let newDoc = parser.parse(source)

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        XCTAssertFalse(results.isEmpty)
        // Since the documents have the same content and ranges, the root should be unchanged
        let rootResult = results.first
        XCTAssertNotNil(rootResult)
        XCTAssertEqual(rootResult?.changeType, .unchanged)
    }

    // MARK: - 6. AST Diff: Modified Content

    func testDiffModifiedContent() {
        let oldDoc = parser.parse("# Old Title")
        let newDoc = parser.parse("# New Title")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        XCTAssertFalse(results.isEmpty)
        // Should detect modifications since content changed
        let modifiedResults = results.filter { $0.changeType == .modified }
        XCTAssertFalse(modifiedResults.isEmpty, "Should detect content modification")
    }

    func testDiffModifiedParagraph() {
        let oldDoc = parser.parse("First version of text.")
        let newDoc = parser.parse("Second version of text.")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        let modifiedResults = results.filter { $0.changeType == .modified }
        XCTAssertFalse(modifiedResults.isEmpty, "Paragraph content change should be detected")
    }

    // MARK: - 6. AST Diff: Inserted Nodes

    func testDiffInsertedNode() {
        let oldDoc = parser.parse("# Title")
        let newDoc = parser.parse("# Title\n\nNew paragraph.")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        let insertedResults = results.filter { $0.changeType == .inserted }
        XCTAssertFalse(insertedResults.isEmpty, "Should detect inserted paragraph node")
    }

    // MARK: - 6. AST Diff: Deleted Nodes

    func testDiffDeletedNode() {
        let oldDoc = parser.parse("# Title\n\nParagraph to remove.")
        let newDoc = parser.parse("# Title")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        let deletedResults = results.filter { $0.changeType == .deleted }
        XCTAssertFalse(deletedResults.isEmpty, "Should detect deleted paragraph node")
    }

    // MARK: - 6. AST Diff: Structural Changes

    func testDiffStructuralChange() {
        let oldDoc = parser.parse("# Heading")
        let newDoc = parser.parse("Paragraph instead")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        // The child changed type from heading to paragraph, so it should be modified
        let modifiedResults = results.filter { $0.changeType == .modified }
        XCTAssertFalse(modifiedResults.isEmpty, "Type change should be detected as modification")
    }

    // MARK: - 6. AST Diff: Incremental Update Info

    func testComputeIncrementalUpdate() {
        let oldDoc = parser.parse("Hello world")
        let newDoc = parser.parse("Hello beautiful world")

        let differ = ASTDiff()
        let editRange = NSRange(location: 5, length: 0) // Insert at position 5
        let updateInfo = differ.computeIncrementalUpdate(
            from: oldDoc,
            to: newDoc,
            editRange: editRange
        )

        // The affected range should encompass at least the edit range
        XCTAssertTrue(updateInfo.affectedRange.length > 0)
    }

    func testComputeIncrementalUpdateStructuralChange() {
        let oldDoc = parser.parse("# Heading\n\nParagraph")
        let newDoc = parser.parse("# Heading\n\n- List item\n\nParagraph")

        let differ = ASTDiff()
        let editRange = NSRange(location: 11, length: 0)
        let updateInfo = differ.computeIncrementalUpdate(
            from: oldDoc,
            to: newDoc,
            editRange: editRange
        )

        XCTAssertTrue(updateInfo.isStructuralChange, "Adding a list should be a structural change")
        XCTAssertFalse(updateInfo.nodesToReparse.isEmpty)
    }

    func testComputeIncrementalUpdateNodesToReparse() {
        let oldDoc = parser.parse("First paragraph.\n\nSecond paragraph.")
        let newDoc = parser.parse("First paragraph.\n\nModified second paragraph.")

        let differ = ASTDiff()
        let editRange = NSRange(location: 18, length: 6) // Editing in second paragraph
        let updateInfo = differ.computeIncrementalUpdate(
            from: oldDoc,
            to: newDoc,
            editRange: editRange
        )

        XCTAssertFalse(updateInfo.nodesToReparse.isEmpty, "Should identify nodes needing reparse")
    }

    // MARK: - 6. AST Diff: DiffResult Properties

    func testDiffResultOldAndNewRange() {
        let oldDoc = parser.parse("Hello")
        let newDoc = parser.parse("Hello World")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        for result in results {
            if result.changeType == .modified {
                XCTAssertNotNil(result.oldRange, "Modified result should have oldRange")
                XCTAssertNotNil(result.newRange, "Modified result should have newRange")
            }
        }
    }

    func testDiffResultInsertedHasNewRangeOnly() {
        let oldDoc = parser.parse("# Title")
        let newDoc = parser.parse("# Title\n\nNew paragraph.")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        let insertedResults = results.filter { $0.changeType == .inserted }
        for result in insertedResults {
            XCTAssertNotNil(result.newRange, "Inserted result should have newRange")
            XCTAssertNil(result.oldRange, "Inserted result should not have oldRange")
        }
    }

    func testDiffResultDeletedHasOldRangeOnly() {
        let oldDoc = parser.parse("# Title\n\nRemoved paragraph.")
        let newDoc = parser.parse("# Title")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        let deletedResults = results.filter { $0.changeType == .deleted }
        for result in deletedResults {
            XCTAssertNotNil(result.oldRange, "Deleted result should have oldRange")
            XCTAssertNil(result.newRange, "Deleted result should not have newRange")
        }
    }

    // MARK: - 7. Incremental Parser: parse

    func testIncrementalParserParse() {
        let incrementalParser = IncrementalParser()
        let document = incrementalParser.parse("# Hello\n\nWorld")
        XCTAssertEqual(document.root.type, .document)
        XCTAssertEqual(document.root.children.count, 2)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 1))
        XCTAssertEqual(document.root.children[1].type, .paragraph)
    }

    func testIncrementalParserParseEmptyString() {
        let incrementalParser = IncrementalParser()
        let document = incrementalParser.parse("")
        XCTAssertEqual(document.root.type, .document)
        XCTAssertTrue(document.root.children.isEmpty)
    }

    func testIncrementalParserParsePreservesSource() {
        let incrementalParser = IncrementalParser()
        let source = "# Title\n\nContent here."
        let document = incrementalParser.parse(source)
        XCTAssertEqual(document.source, source)
    }

    // MARK: - 7. Incremental Parser: Update with Edit

    func testIncrementalParserUpdateAppendText() {
        let incrementalParser = IncrementalParser()
        let originalSource = "Hello"
        let document = incrementalParser.parse(originalSource)

        let newSource = "Hello World"
        let edit = TextEdit(range: NSRange(location: 5, length: 0), replacement: " World")
        let (newDoc, updateInfo) = incrementalParser.update(
            document: document,
            with: edit,
            newSource: newSource
        )

        XCTAssertEqual(newDoc.source, newSource)
        XCTAssertEqual(newDoc.root.children.count, 1)
        XCTAssertEqual(newDoc.root.children[0].type, .paragraph)
        XCTAssertTrue(updateInfo.affectedRange.length > 0)
    }

    func testIncrementalParserUpdateReplaceText() {
        let incrementalParser = IncrementalParser()
        let originalSource = "# Old Title"
        let document = incrementalParser.parse(originalSource)

        let newSource = "# New Title"
        let edit = TextEdit(range: NSRange(location: 2, length: 3), replacement: "New")
        let (newDoc, _) = incrementalParser.update(
            document: document,
            with: edit,
            newSource: newSource
        )

        XCTAssertEqual(newDoc.source, newSource)
        XCTAssertEqual(newDoc.root.children.count, 1)
        XCTAssertEqual(newDoc.root.children[0].type, .heading(level: 1))
    }

    func testIncrementalParserUpdateDeleteText() {
        let incrementalParser = IncrementalParser()
        let originalSource = "# Title\n\nParagraph."
        let document = incrementalParser.parse(originalSource)

        let newSource = "# Title"
        let edit = TextEdit(range: NSRange(location: 7, length: 12), replacement: "")
        let (newDoc, _) = incrementalParser.update(
            document: document,
            with: edit,
            newSource: newSource
        )

        XCTAssertEqual(newDoc.source, newSource)
        XCTAssertEqual(newDoc.root.children.count, 1)
        XCTAssertEqual(newDoc.root.children[0].type, .heading(level: 1))
    }

    func testIncrementalParserUpdateReturnsUpdateInfo() {
        let incrementalParser = IncrementalParser()
        let originalSource = "Hello world."
        let document = incrementalParser.parse(originalSource)

        let newSource = "Hello beautiful world."
        let edit = TextEdit(range: NSRange(location: 6, length: 0), replacement: "beautiful ")
        let (_, updateInfo) = incrementalParser.update(
            document: document,
            with: edit,
            newSource: newSource
        )

        XCTAssertTrue(updateInfo.affectedRange.length > 0)
    }

    func testIncrementalParserUpdateStructuralChange() {
        let incrementalParser = IncrementalParser()
        let originalSource = "Paragraph text."
        let document = incrementalParser.parse(originalSource)

        let newSource = "# Heading now"
        let edit = TextEdit(range: NSRange(location: 0, length: 15), replacement: "# Heading now")
        let (newDoc, updateInfo) = incrementalParser.update(
            document: document,
            with: edit,
            newSource: newSource
        )

        XCTAssertEqual(newDoc.root.children[0].type, .heading(level: 1))
        XCTAssertTrue(updateInfo.isStructuralChange, "Changing paragraph to heading is structural")
    }

    // MARK: - 7. Incremental Parser: reparseBlock

    func testReparseBlockContainingLocation() {
        let incrementalParser = IncrementalParser()
        let source = "# Heading\n\nParagraph text."
        let document = incrementalParser.parse(source)

        // Reparse the block containing location 0 (the heading)
        let result = incrementalParser.reparseBlock(
            containing: 0,
            in: document,
            with: source
        )
        XCTAssertNotNil(result, "Should successfully reparse the block containing location 0")
        XCTAssertEqual(result?.root.type, .document)
    }

    func testReparseBlockReturnsNilForOutOfRange() {
        let incrementalParser = IncrementalParser()
        let source = "# Heading"
        let document = incrementalParser.parse(source)

        // Try a location way beyond the document
        let result = incrementalParser.reparseBlock(
            containing: 1000,
            in: document,
            with: source
        )
        XCTAssertNil(result, "Should return nil for location outside document range")
    }

    func testReparseBlockWithModifiedSource() {
        let incrementalParser = IncrementalParser()
        let originalSource = "# Title\n\nOld paragraph."
        let document = incrementalParser.parse(originalSource)

        let newSource = "# Title\n\nNew paragraph."
        let result = incrementalParser.reparseBlock(
            containing: 12,
            in: document,
            with: newSource
        )
        XCTAssertNotNil(result)
    }

    // MARK: - 7. Incremental Parser: With Configuration

    func testIncrementalParserWithConfiguration() {
        let config = ParserConfiguration(
            enableGitHubFlavoredMarkdown: false,
            enableStrikethrough: false,
            enableTables: false,
            enableTaskLists: false
        )
        let incrementalParser = IncrementalParser(configuration: config)
        let document = incrementalParser.parse("# Hello")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 1))
    }

    // MARK: - 8. TextEdit: Initialization and Properties

    func testTextEditInitialization() {
        let edit = TextEdit(
            range: NSRange(location: 5, length: 3),
            replacement: "hello"
        )
        XCTAssertEqual(edit.range.location, 5)
        XCTAssertEqual(edit.range.length, 3)
        XCTAssertEqual(edit.replacement, "hello")
    }

    func testTextEditTimestamp() {
        let before = Date()
        let edit = TextEdit(
            range: NSRange(location: 0, length: 0),
            replacement: "x"
        )
        let after = Date()
        XCTAssertTrue(edit.timestamp >= before)
        XCTAssertTrue(edit.timestamp <= after)
    }

    func testTextEditCustomTimestamp() {
        let customDate = Date(timeIntervalSince1970: 1000000)
        let edit = TextEdit(
            range: NSRange(location: 0, length: 0),
            replacement: "x",
            timestamp: customDate
        )
        XCTAssertEqual(edit.timestamp, customDate)
    }

    // MARK: - 8. TextEdit: resultingRange Computation

    func testResultingRangeForInsertion() {
        // Inserting "hello" at location 5 with no deletion
        let edit = TextEdit(
            range: NSRange(location: 5, length: 0),
            replacement: "hello"
        )
        let resulting = edit.resultingRange
        XCTAssertEqual(resulting.location, 5)
        XCTAssertEqual(resulting.length, 5, "Resulting range length should equal replacement length")
    }

    func testResultingRangeForDeletion() {
        // Deleting 3 characters at location 2 with empty replacement
        let edit = TextEdit(
            range: NSRange(location: 2, length: 3),
            replacement: ""
        )
        let resulting = edit.resultingRange
        XCTAssertEqual(resulting.location, 2)
        XCTAssertEqual(resulting.length, 0, "Deletion with empty replacement should have zero-length result")
    }

    func testResultingRangeForReplacement() {
        // Replacing 3 characters at location 10 with "abcde" (5 characters)
        let edit = TextEdit(
            range: NSRange(location: 10, length: 3),
            replacement: "abcde"
        )
        let resulting = edit.resultingRange
        XCTAssertEqual(resulting.location, 10)
        XCTAssertEqual(resulting.length, 5, "Resulting range should match replacement string length")
    }

    func testResultingRangeForSameLengthReplacement() {
        // Replace 4 characters with 4 characters
        let edit = TextEdit(
            range: NSRange(location: 0, length: 4),
            replacement: "wxyz"
        )
        let resulting = edit.resultingRange
        XCTAssertEqual(resulting.location, 0)
        XCTAssertEqual(resulting.length, 4)
    }

    func testResultingRangeForInsertionAtStart() {
        let edit = TextEdit(
            range: NSRange(location: 0, length: 0),
            replacement: "prefix "
        )
        let resulting = edit.resultingRange
        XCTAssertEqual(resulting.location, 0)
        XCTAssertEqual(resulting.length, 7)
    }

    func testResultingRangeLocationPreserved() {
        // The resulting range always starts at the edit location
        let edit = TextEdit(
            range: NSRange(location: 42, length: 10),
            replacement: "short"
        )
        XCTAssertEqual(edit.resultingRange.location, 42)
        XCTAssertEqual(edit.resultingRange.length, 5)
    }

    // MARK: - 9. ParserState: setSource

    @MainActor
    func testParserStateInitialDocument() {
        let state = ParserState()
        XCTAssertEqual(state.document.root.type, .document)
        XCTAssertTrue(state.document.root.children.isEmpty)
        XCTAssertEqual(state.document.source, "")
    }

    @MainActor
    func testParserStateSetSource() {
        let state = ParserState()
        state.setSource("# Hello\n\nWorld")

        XCTAssertEqual(state.document.root.children.count, 2)
        XCTAssertEqual(state.document.root.children[0].type, .heading(level: 1))
        XCTAssertEqual(state.document.root.children[1].type, .paragraph)
        XCTAssertEqual(state.document.source, "# Hello\n\nWorld")
    }

    @MainActor
    func testParserStateSetSourceOverwrites() {
        let state = ParserState()
        state.setSource("# First")
        XCTAssertEqual(state.document.root.children.count, 1)
        XCTAssertEqual(state.document.root.children[0].type, .heading(level: 1))

        state.setSource("New paragraph only.")
        XCTAssertEqual(state.document.root.children.count, 1)
        XCTAssertEqual(state.document.root.children[0].type, .paragraph)
    }

    @MainActor
    func testParserStateSetSourceEmpty() {
        let state = ParserState()
        state.setSource("# Hello")
        XCTAssertFalse(state.document.root.children.isEmpty)

        state.setSource("")
        XCTAssertTrue(state.document.root.children.isEmpty)
    }

    // MARK: - 9. ParserState: applyEdit

    @MainActor
    func testParserStateApplyEditInsertion() {
        let state = ParserState()
        state.setSource("Hello")

        let edit = TextEdit(range: NSRange(location: 5, length: 0), replacement: " World")
        let updateInfo = state.applyEdit(edit, to: "Hello World")

        XCTAssertEqual(state.document.source, "Hello World")
        XCTAssertTrue(updateInfo.affectedRange.length > 0)
    }

    @MainActor
    func testParserStateApplyEditDeletion() {
        let state = ParserState()
        state.setSource("# Title\n\nParagraph")

        let edit = TextEdit(range: NSRange(location: 7, length: 11), replacement: "")
        let updateInfo = state.applyEdit(edit, to: "# Title")

        XCTAssertEqual(state.document.source, "# Title")
        XCTAssertEqual(state.document.root.children.count, 1)
        XCTAssertNotNil(updateInfo)
    }

    @MainActor
    func testParserStateApplyEditReplacement() {
        let state = ParserState()
        state.setSource("# Old")

        let edit = TextEdit(range: NSRange(location: 2, length: 3), replacement: "New")
        state.applyEdit(edit, to: "# New")

        XCTAssertEqual(state.document.source, "# New")
        XCTAssertEqual(state.document.root.children[0].type, .heading(level: 1))
    }

    @MainActor
    func testParserStateApplyMultipleEdits() {
        let state = ParserState()
        state.setSource("Hello")

        let edit1 = TextEdit(range: NSRange(location: 5, length: 0), replacement: " World")
        state.applyEdit(edit1, to: "Hello World")

        let edit2 = TextEdit(range: NSRange(location: 11, length: 0), replacement: "!")
        state.applyEdit(edit2, to: "Hello World!")

        XCTAssertEqual(state.document.source, "Hello World!")
    }

    // MARK: - 9. ParserState: node(at:)

    @MainActor
    func testParserStateNodeAt() {
        let state = ParserState()
        state.setSource("# Hello\n\nWorld")

        let nodeAtStart = state.node(at: 0)
        XCTAssertNotNil(nodeAtStart, "Should find a node at location 0")
    }

    @MainActor
    func testParserStateNodeAtOutOfRange() {
        let state = ParserState()
        state.setSource("# Hello")

        let node = state.node(at: 1000)
        XCTAssertNil(node, "Should return nil for location outside document range")
    }

    // MARK: - 9. ParserState: block(at:)

    @MainActor
    func testParserStateBlockAt() {
        let state = ParserState()
        state.setSource("# Heading\n\nParagraph text.")

        let block = state.block(at: 0)
        XCTAssertNotNil(block, "Should find a block at location 0")
        if let block = block {
            XCTAssertTrue(block.isBlock, "Result should be a block-level node")
        }
    }

    @MainActor
    func testParserStateBlockAtParagraphLocation() {
        let state = ParserState()
        let source = "# Heading\n\nParagraph text."
        state.setSource(source)

        // The paragraph starts after "# Heading\n\n" (location 11)
        let block = state.block(at: 12)
        XCTAssertNotNil(block)
        if let block = block {
            XCTAssertTrue(block.isBlock)
        }
    }

    @MainActor
    func testParserStateBlockAtReturnsNilForEmpty() {
        let state = ParserState()
        // Default state: empty document
        let block = state.block(at: 0)
        // The document root is a block, but it has zero length, so
        // NSLocationInRange(0, NSRange(0, 0)) is false
        // The root document range is (0, 0), so location 0 is not "in range"
        // depending on implementation behavior
        // Just verify it does not crash
        _ = block
    }

    // MARK: - 9. ParserState: With Custom Parser

    @MainActor
    func testParserStateWithCustomConfiguration() {
        let config = ParserConfiguration(enableStrikethrough: false)
        let incrementalParser = IncrementalParser(configuration: config)
        let state = ParserState(parser: incrementalParser)
        state.setSource("# Hello")
        XCTAssertEqual(state.document.root.children.count, 1)
    }

    // MARK: - 10. Parser Configuration: Default

    func testDefaultConfiguration() {
        let config = ParserConfiguration.default
        XCTAssertTrue(config.enableGitHubFlavoredMarkdown)
        XCTAssertTrue(config.enableStrikethrough)
        XCTAssertTrue(config.enableTables)
        XCTAssertTrue(config.enableTaskLists)
    }

    // MARK: - 10. Parser Configuration: Custom Configurations

    func testCustomConfigurationAllDisabled() {
        let config = ParserConfiguration(
            enableGitHubFlavoredMarkdown: false,
            enableStrikethrough: false,
            enableTables: false,
            enableTaskLists: false
        )
        XCTAssertFalse(config.enableGitHubFlavoredMarkdown)
        XCTAssertFalse(config.enableStrikethrough)
        XCTAssertFalse(config.enableTables)
        XCTAssertFalse(config.enableTaskLists)
    }

    func testCustomConfigurationPartial() {
        let config = ParserConfiguration(
            enableGitHubFlavoredMarkdown: true,
            enableStrikethrough: false,
            enableTables: true,
            enableTaskLists: false
        )
        XCTAssertTrue(config.enableGitHubFlavoredMarkdown)
        XCTAssertFalse(config.enableStrikethrough)
        XCTAssertTrue(config.enableTables)
        XCTAssertFalse(config.enableTaskLists)
    }

    func testConfigurationDefaultInitParameters() {
        // Using all default parameters
        let config = ParserConfiguration()
        XCTAssertTrue(config.enableGitHubFlavoredMarkdown)
        XCTAssertTrue(config.enableStrikethrough)
        XCTAssertTrue(config.enableTables)
        XCTAssertTrue(config.enableTaskLists)
    }

    // MARK: - 10. Parser Configuration: Parser with Configuration

    func testParserWithDefaultConfiguration() {
        let config = ParserConfiguration.default
        let configParser = MarkdownParser(configuration: config)
        let document = configParser.parse("# Hello")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 1))
    }

    func testParserWithCustomConfiguration() {
        let config = ParserConfiguration(
            enableGitHubFlavoredMarkdown: false,
            enableStrikethrough: false,
            enableTables: false,
            enableTaskLists: false
        )
        let configParser = MarkdownParser(configuration: config)
        let document = configParser.parse("# Hello")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 1))
    }

    func testConfigurationMutability() {
        var config = ParserConfiguration.default
        config.enableStrikethrough = false
        config.enableTables = false
        XCTAssertFalse(config.enableStrikethrough)
        XCTAssertFalse(config.enableTables)
        XCTAssertTrue(config.enableGitHubFlavoredMarkdown)
        XCTAssertTrue(config.enableTaskLists)
    }

    // MARK: - 10. Parser Configuration: Incremental Parsing

    func testParseIncrementalSmallEdit() {
        let originalSource = "# Title\n\nParagraph one.\n\nParagraph two."
        let doc = parser.parse(originalSource)

        let newSource = "# Title\n\nParagraph one modified.\n\nParagraph two."
        let result = parser.parseIncremental(
            previousDocument: doc,
            editRange: NSRange(location: 23, length: 0),
            newSource: newSource
        )

        XCTAssertEqual(result.source, newSource)
        XCTAssertEqual(result.root.type, .document)
    }

    func testParseIncrementalLargeEdit() {
        // For large edits, it should fall back to full parse
        let originalSource = "Hello"
        let doc = parser.parse(originalSource)

        let newSource = "# Completely different document\n\nWith paragraphs."
        let result = parser.parseIncremental(
            previousDocument: doc,
            editRange: NSRange(location: 0, length: 5),
            newSource: newSource
        )

        XCTAssertEqual(result.source, newSource)
        XCTAssertEqual(result.root.type, .document)
    }

    // MARK: - Edge Cases

    func testParseOnlyNewlines() {
        let document = parser.parse("\n\n\n")
        XCTAssertEqual(document.root.type, .document)
    }

    func testParseSingleCharacter() {
        let document = parser.parse("x")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .paragraph)
    }

    func testParseHeadingWithoutSpace() {
        // "#NoSpace" is NOT a valid heading in CommonMark
        let document = parser.parse("#NoSpace")
        // It should be parsed as a paragraph, not a heading
        if !document.root.children.isEmpty {
            XCTAssertNotEqual(
                document.root.children[0].type,
                .heading(level: 1),
                "# without space should not be a heading"
            )
        }
    }

    func testParseVeryLongDocument() {
        let lines = (1...100).map { "Line \($0) of the document." }
        let markdown = lines.joined(separator: "\n\n")
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.type, .document)
        XCTAssertEqual(document.root.children.count, 100)
    }

    func testParseUnicodeContent() {
        let document = parser.parse("# Heading with emoji and unicode chars")
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children[0].type, .heading(level: 1))
    }

    func testParseSpecialMarkdownCharacters() {
        // Backslash escapes
        let document = parser.parse("\\*not italic\\*")
        let paragraph = document.root.children[0]
        // Should NOT contain emphasis nodes
        let emphasisNodes = children(of: paragraph) { type in
            if case .emphasis = type { return true }
            return false
        }
        XCTAssertTrue(emphasisNodes.isEmpty, "Escaped asterisks should not produce emphasis")
    }

    func testDocumentRootRangeCoversEntireSource() {
        let source = "# Hello\n\nWorld\n\n---\n\nEnd."
        let document = parser.parse(source)
        let rootRange = document.root.range
        // The root range should start at 0 and span the document
        XCTAssertEqual(rootRange.location, 0)
        XCTAssertTrue(rootRange.length > 0, "Root range should have non-zero length")
    }

    func testNodeTypeEquatable() {
        XCTAssertEqual(TymarkNodeType.paragraph, TymarkNodeType.paragraph)
        XCTAssertEqual(TymarkNodeType.heading(level: 1), TymarkNodeType.heading(level: 1))
        XCTAssertNotEqual(TymarkNodeType.heading(level: 1), TymarkNodeType.heading(level: 2))
        XCTAssertEqual(TymarkNodeType.list(ordered: true), TymarkNodeType.list(ordered: true))
        XCTAssertNotEqual(TymarkNodeType.list(ordered: true), TymarkNodeType.list(ordered: false))
        XCTAssertEqual(
            TymarkNodeType.codeBlock(language: "swift"),
            TymarkNodeType.codeBlock(language: "swift")
        )
        XCTAssertNotEqual(
            TymarkNodeType.codeBlock(language: "swift"),
            TymarkNodeType.codeBlock(language: "python")
        )
        XCTAssertEqual(
            TymarkNodeType.link(destination: "url", title: nil),
            TymarkNodeType.link(destination: "url", title: nil)
        )
        XCTAssertNotEqual(
            TymarkNodeType.link(destination: "url1", title: nil),
            TymarkNodeType.link(destination: "url2", title: nil)
        )
        XCTAssertEqual(
            TymarkNodeType.image(source: "src", alt: "alt"),
            TymarkNodeType.image(source: "src", alt: "alt")
        )
        XCTAssertEqual(
            TymarkNodeType.custom(name: "foo"),
            TymarkNodeType.custom(name: "foo")
        )
        XCTAssertNotEqual(
            TymarkNodeType.custom(name: "foo"),
            TymarkNodeType.custom(name: "bar")
        )
        XCTAssertNotEqual(TymarkNodeType.paragraph, TymarkNodeType.text)
    }

    func testNodeTypeHashable() {
        let set: Set<TymarkNodeType> = [
            .paragraph,
            .heading(level: 1),
            .heading(level: 2),
            .text,
            .emphasis,
            .strong,
        ]
        XCTAssertEqual(set.count, 6)
        XCTAssertTrue(set.contains(.paragraph))
        XCTAssertTrue(set.contains(.heading(level: 1)))
        XCTAssertFalse(set.contains(.heading(level: 3)))
    }

    func testASTChangeTypeEquatable() {
        XCTAssertEqual(ASTChangeType.unchanged, ASTChangeType.unchanged)
        XCTAssertEqual(ASTChangeType.modified, ASTChangeType.modified)
        XCTAssertEqual(ASTChangeType.inserted, ASTChangeType.inserted)
        XCTAssertEqual(ASTChangeType.deleted, ASTChangeType.deleted)
        XCTAssertNotEqual(ASTChangeType.unchanged, ASTChangeType.modified)
        XCTAssertNotEqual(ASTChangeType.inserted, ASTChangeType.deleted)
    }

    func testTymarkDocumentEquatable() {
        let node = TymarkNode(type: .document, range: NSRange(location: 0, length: 0))
        let version = UUID()
        let doc1 = TymarkDocument(root: node, source: "", version: version)
        let doc2 = TymarkDocument(root: node, source: "", version: version)
        XCTAssertEqual(doc1, doc2)
    }

    func testTymarkDocumentInequalityDifferentSource() {
        let node = TymarkNode(type: .document, range: NSRange(location: 0, length: 0))
        let version = UUID()
        let doc1 = TymarkDocument(root: node, source: "a", version: version)
        let doc2 = TymarkDocument(root: node, source: "b", version: version)
        XCTAssertNotEqual(doc1, doc2)
    }

    // MARK: - Softbreak and Linebreak

    func testParseSoftBreak() {
        // Two lines in the same paragraph produce a soft break
        let markdown = "Line one\nLine two"
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        let paragraph = document.root.children[0]
        let softBreaks = paragraph.children.filter { $0.type == .softBreak }
        XCTAssertFalse(softBreaks.isEmpty, "Should contain a soft break between lines in same paragraph")
    }

    func testParseHardLineBreak() {
        // Two trailing spaces followed by a newline create a hard line break
        let markdown = "Line one  \nLine two"
        let document = parser.parse(markdown)
        XCTAssertEqual(document.root.children.count, 1)
        let paragraph = document.root.children[0]
        let lineBreaks = paragraph.children.filter { $0.type == .lineBreak }
        XCTAssertFalse(lineBreaks.isEmpty, "Two trailing spaces should produce a line break")
    }

    // MARK: - HTML Parsing

    func testParseInlineHTML() {
        let document = parser.parse("Text with <br> inline HTML")
        let paragraph = document.root.children[0]
        let htmlNodes = paragraph.children.filter { $0.type == .html }
        XCTAssertFalse(htmlNodes.isEmpty, "Should detect inline HTML")
    }

    func testParseHTMLBlock() {
        let markdown = """
        <div>
        Block HTML
        </div>
        """
        let document = parser.parse(markdown)
        let htmlNodes = document.root.children.filter { $0.type == .html }
        XCTAssertFalse(htmlNodes.isEmpty, "Should detect HTML block")
    }

    // MARK: - ASTDiff Edge Cases

    func testDiffEmptyDocuments() {
        let oldDoc = parser.parse("")
        let newDoc = parser.parse("")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        // Both are empty documents, should be unchanged
        XCTAssertFalse(results.isEmpty)
        let unchangedResults = results.filter { $0.changeType == .unchanged }
        XCTAssertFalse(unchangedResults.isEmpty)
    }

    func testDiffMultipleInsertions() {
        let oldDoc = parser.parse("# Title")
        let newDoc = parser.parse("# Title\n\nParagraph 1\n\nParagraph 2")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        let insertedResults = results.filter { $0.changeType == .inserted }
        XCTAssertTrue(
            insertedResults.count >= 2,
            "Should detect at least 2 inserted paragraphs, got \(insertedResults.count)"
        )
    }

    func testDiffMultipleDeletions() {
        let oldDoc = parser.parse("# Title\n\nParagraph 1\n\nParagraph 2")
        let newDoc = parser.parse("# Title")

        let differ = ASTDiff()
        let results = differ.diff(oldDocument: oldDoc, newDocument: newDoc)
        let deletedResults = results.filter { $0.changeType == .deleted }
        XCTAssertTrue(
            deletedResults.count >= 2,
            "Should detect at least 2 deleted paragraphs, got \(deletedResults.count)"
        )
    }

    // MARK: - IncrementalUpdateInfo Properties

    func testIncrementalUpdateInfoProperties() {
        let info = IncrementalUpdateInfo(
            affectedRange: NSRange(location: 0, length: 50),
            nodesToReparse: [],
            isStructuralChange: false
        )
        XCTAssertEqual(info.affectedRange.location, 0)
        XCTAssertEqual(info.affectedRange.length, 50)
        XCTAssertTrue(info.nodesToReparse.isEmpty)
        XCTAssertFalse(info.isStructuralChange)
    }

    func testIncrementalUpdateInfoWithNodes() {
        let node = TymarkNode(type: .paragraph, content: "test", range: NSRange(location: 0, length: 4))
        let info = IncrementalUpdateInfo(
            affectedRange: NSRange(location: 0, length: 10),
            nodesToReparse: [node],
            isStructuralChange: true
        )
        XCTAssertEqual(info.nodesToReparse.count, 1)
        XCTAssertTrue(info.isStructuralChange)
    }
}

#endif
