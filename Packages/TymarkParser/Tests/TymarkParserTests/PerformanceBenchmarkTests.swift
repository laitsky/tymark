import XCTest
@testable import TymarkParser

// MARK: - Performance Benchmark Tests

/// Performance benchmarks for the Tymark parser pipeline.
/// These tests use XCTest's `measure` to track performance regressions
/// across parser, incremental update, and AST diff operations.
final class PerformanceBenchmarkTests: XCTestCase {

    // MARK: - Properties

    private var parser: MarkdownParser!
    private var incrementalParser: IncrementalParser!
    private var diffEngine: ASTDiff!

    // MARK: - Test Data

    /// Generates a markdown document of approximately the given line count.
    private func generateMarkdown(lines: Int) -> String {
        var parts: [String] = []
        var lineCount = 0

        while lineCount < lines {
            let section = lineCount / 20
            parts.append("# Section \(section + 1)")
            lineCount += 1

            parts.append("")
            lineCount += 1

            parts.append("This is a paragraph with **bold text**, *italic text*, and `inline code`.")
            lineCount += 1

            parts.append("")
            lineCount += 1

            parts.append("Another paragraph with a [link](https://example.com) and some more text to make it longer.")
            lineCount += 1

            parts.append("")
            lineCount += 1

            parts.append("- Item one with content")
            parts.append("- Item two with content")
            parts.append("- Item three with content")
            lineCount += 3

            parts.append("")
            lineCount += 1

            parts.append("1. First ordered item")
            parts.append("2. Second ordered item")
            parts.append("3. Third ordered item")
            lineCount += 3

            parts.append("")
            lineCount += 1

            parts.append("> This is a blockquote with some text that spans a single line.")
            lineCount += 1

            parts.append("")
            lineCount += 1

            parts.append("```swift")
            parts.append("func example() {")
            parts.append("    let x = 42")
            parts.append("    print(x)")
            parts.append("}")
            parts.append("```")
            lineCount += 6

            parts.append("")
            lineCount += 1
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        parser = MarkdownParser()
        incrementalParser = IncrementalParser()
        diffEngine = ASTDiff()
    }

    override func tearDown() {
        parser = nil
        incrementalParser = nil
        diffEngine = nil
        super.tearDown()
    }

    // MARK: - Parser Performance

    func testParseSmallDocument() {
        let markdown = generateMarkdown(lines: 50)

        measure {
            _ = parser.parse(markdown)
        }
    }

    func testParseMediumDocument() {
        let markdown = generateMarkdown(lines: 500)

        measure {
            _ = parser.parse(markdown)
        }
    }

    func testParseLargeDocument() {
        let markdown = generateMarkdown(lines: 2000)

        measure {
            _ = parser.parse(markdown)
        }
    }

    func testParseVeryLargeDocument() {
        let markdown = generateMarkdown(lines: 10000)

        measure {
            _ = parser.parse(markdown)
        }
    }

    // MARK: - Incremental Parser Performance

    func testIncrementalParseInitial() {
        let markdown = generateMarkdown(lines: 1000)

        measure {
            _ = incrementalParser.parse(markdown)
        }
    }

    func testIncrementalUpdateSmallEdit() {
        let markdown = generateMarkdown(lines: 1000)
        let document = incrementalParser.parse(markdown)

        // Simulate a small edit in the middle of the document
        let editLocation = markdown.count / 2
        let edit = TextEdit(
            range: NSRange(location: editLocation, length: 0),
            replacement: "inserted text"
        )
        let newSource = (markdown as NSString).replacingCharacters(
            in: edit.range,
            with: edit.replacement
        )

        measure {
            _ = incrementalParser.update(document: document, with: edit, newSource: newSource)
        }
    }

    func testIncrementalUpdateLargeEdit() {
        let markdown = generateMarkdown(lines: 1000)
        let document = incrementalParser.parse(markdown)

        // Simulate replacing a large chunk
        let editStart = markdown.count / 4
        let editLength = min(200, markdown.count - editStart)
        let edit = TextEdit(
            range: NSRange(location: editStart, length: editLength),
            replacement: "# New Heading\n\nReplaced content with a new paragraph and **bold** text.\n\n- New list item\n"
        )
        let newSource = (markdown as NSString).replacingCharacters(
            in: edit.range,
            with: edit.replacement
        )

        measure {
            _ = incrementalParser.update(document: document, with: edit, newSource: newSource)
        }
    }

    func testIncrementalReparseBlock() {
        let markdown = generateMarkdown(lines: 1000)
        let document = incrementalParser.parse(markdown)

        // Pick a location in the middle
        let location = markdown.count / 2
        let newSource = (markdown as NSString).replacingCharacters(
            in: NSRange(location: location, length: 5),
            with: "REPLACED"
        )

        measure {
            _ = incrementalParser.reparseBlock(containing: location, in: document, with: newSource)
        }
    }

    // MARK: - AST Diff Performance

    func testDiffIdenticalDocuments() {
        let markdown = generateMarkdown(lines: 500)
        let doc1 = parser.parse(markdown)
        let doc2 = parser.parse(markdown)

        measure {
            _ = diffEngine.diff(oldDocument: doc1, newDocument: doc2)
        }
    }

    func testDiffSmallChange() {
        let markdown = generateMarkdown(lines: 500)
        let doc1 = parser.parse(markdown)

        // Make a small change
        let modified = markdown.replacingOccurrences(of: "Section 5", with: "Modified Section 5")
        let doc2 = parser.parse(modified)

        measure {
            _ = diffEngine.diff(oldDocument: doc1, newDocument: doc2)
        }
    }

    func testDiffLargeChange() {
        let markdown = generateMarkdown(lines: 500)
        let doc1 = parser.parse(markdown)

        // Make large changes
        var modified = markdown
        modified = modified.replacingOccurrences(of: "bold text", with: "completely changed text")
        modified = modified.replacingOccurrences(of: "inline code", with: "different code")
        modified = modified.replacingOccurrences(of: "Item one", with: "First item replaced")
        let doc2 = parser.parse(modified)

        measure {
            _ = diffEngine.diff(oldDocument: doc1, newDocument: doc2)
        }
    }

    func testComputeIncrementalUpdate() {
        let markdown = generateMarkdown(lines: 500)
        let doc1 = parser.parse(markdown)

        let editRange = NSRange(location: markdown.count / 2, length: 10)
        let modified = (markdown as NSString).replacingCharacters(in: editRange, with: "new content")
        let doc2 = parser.parse(modified)

        measure {
            _ = diffEngine.computeIncrementalUpdate(from: doc1, to: doc2, editRange: editRange)
        }
    }

    // MARK: - AST Traversal Performance

    func testNodeLookupByLocation() {
        let markdown = generateMarkdown(lines: 1000)
        let document = parser.parse(markdown)

        measure {
            // Simulate looking up nodes at various locations
            for i in stride(from: 0, to: markdown.count, by: markdown.count / 100) {
                _ = document.root.node(at: i)
            }
        }
    }

    func testChildPathNavigation() {
        let markdown = generateMarkdown(lines: 500)
        let document = parser.parse(markdown)
        let childCount = document.root.children.count

        measure {
            for i in 0..<min(childCount, 50) {
                _ = document.root.child(at: [i])
                if document.root.children[i].children.count > 0 {
                    _ = document.root.child(at: [i, 0])
                }
            }
        }
    }

    // MARK: - Memory Stress Tests

    func testParseAndDiscardRepeated() {
        let markdown = generateMarkdown(lines: 200)

        measure {
            for _ in 0..<50 {
                autoreleasepool {
                    _ = parser.parse(markdown)
                }
            }
        }
    }

    func testRapidIncrementalUpdates() {
        let markdown = generateMarkdown(lines: 500)
        var document = incrementalParser.parse(markdown)
        var currentSource = markdown

        measure {
            for i in 0..<20 {
                let loc = min(i * 50, currentSource.count - 1)
                let edit = TextEdit(
                    range: NSRange(location: loc, length: 0),
                    replacement: "x"
                )
                let newSource = (currentSource as NSString).replacingCharacters(
                    in: edit.range,
                    with: edit.replacement
                )
                let result = incrementalParser.update(document: document, with: edit, newSource: newSource)
                document = result.document
                currentSource = newSource
            }
        }
    }
}
