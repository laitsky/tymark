#if canImport(XCTest)
import XCTest
@testable import TymarkExport
import TymarkParser
import TymarkTheme

final class TymarkExportTests: XCTestCase {

    // MARK: - Helpers

    private let parser = MarkdownParser()
    private let theme = BuiltInThemes.light

    private func parseDocument(_ markdown: String) -> TymarkDocument {
        return parser.parse(markdown)
    }

    private func exportHTML(_ markdown: String) -> String? {
        let document = parseDocument(markdown)
        let exporter = HTMLExporter()
        guard let data = exporter.export(document: document, theme: theme) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - HTMLExporter: Properties

    func testHTMLExporterFileExtension() {
        let exporter = HTMLExporter()
        XCTAssertEqual(exporter.fileExtension, "html")
    }

    func testHTMLExporterMimeType() {
        let exporter = HTMLExporter()
        XCTAssertEqual(exporter.mimeType, "text/html")
    }

    // MARK: - HTMLExporter: Basic Export

    func testHTMLExporterExportsNonNilDataForValidDocument() {
        let document = parseDocument("# Hello\n\nSome text")
        let exporter = HTMLExporter()
        let data = exporter.export(document: document, theme: theme)
        XCTAssertNotNil(data, "HTML export should produce non-nil data for a valid document")
    }

    func testHTMLExporterOutputContainsDOCTYPE() {
        let html = exportHTML("# Hello")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<!DOCTYPE html>"), "HTML output should contain DOCTYPE declaration")
    }

    func testHTMLExporterOutputContainsHtmlTags() {
        let html = exportHTML("# Hello")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<html"), "HTML output should contain opening html tag")
        XCTAssertTrue(html!.contains("</html>"), "HTML output should contain closing html tag")
    }

    func testHTMLExporterOutputContainsHeadAndBody() {
        let html = exportHTML("# Hello")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<head>"), "HTML output should contain head tag")
        XCTAssertTrue(html!.contains("</head>"), "HTML output should contain closing head tag")
        XCTAssertTrue(html!.contains("<body>"), "HTML output should contain body tag")
        XCTAssertTrue(html!.contains("</body>"), "HTML output should contain closing body tag")
    }

    func testHTMLExporterOutputContainsStyleTag() {
        let html = exportHTML("# Hello")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<style>"), "HTML output should contain a style tag with CSS")
        XCTAssertTrue(html!.contains("</style>"), "HTML output should contain closing style tag")
    }

    // MARK: - HTMLExporter: Theme CSS

    func testHTMLExporterIncludesTextColorFromTheme() {
        let html = exportHTML("Some text")
        XCTAssertNotNil(html)
        let textHex = theme.colors.text.hexString
        XCTAssertTrue(html!.contains(textHex), "HTML CSS should include the theme text color \(textHex)")
    }

    func testHTMLExporterIncludesBackgroundColorFromTheme() {
        let html = exportHTML("Some text")
        XCTAssertNotNil(html)
        let bgHex = theme.colors.background.hexString
        XCTAssertTrue(html!.contains(bgHex), "HTML CSS should include the theme background color \(bgHex)")
    }

    func testHTMLExporterIncludesLinkColorFromTheme() {
        let html = exportHTML("[link](https://example.com)")
        XCTAssertNotNil(html)
        let linkHex = theme.colors.link.hexString
        XCTAssertTrue(html!.contains(linkHex), "HTML CSS should include the theme link color \(linkHex)")
    }

    func testHTMLExporterIncludesHeadingColorFromTheme() {
        let html = exportHTML("# Heading")
        XCTAssertNotNil(html)
        let headingHex = theme.colors.heading.hexString
        XCTAssertTrue(html!.contains(headingHex), "HTML CSS should include the theme heading color \(headingHex)")
    }

    func testHTMLExporterIncludesCodeBackgroundColorFromTheme() {
        let html = exportHTML("`code`")
        XCTAssertNotNil(html)
        let codeBgHex = theme.colors.codeBackground.hexString
        XCTAssertTrue(html!.contains(codeBgHex), "HTML CSS should include the theme code background color \(codeBgHex)")
    }

    // MARK: - HTMLExporter: Heading Rendering

    func testHTMLExporterRendersH1() {
        let html = exportHTML("# Hello")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<h1>"), "HTML should contain <h1> tag for level-1 heading")
        XCTAssertTrue(html!.contains("</h1>"), "HTML should contain closing </h1> tag")
        XCTAssertTrue(html!.contains("Hello"), "HTML should contain the heading text")
    }

    func testHTMLExporterRendersH2() {
        let html = exportHTML("## Subheading")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<h2>"), "HTML should contain <h2> tag for level-2 heading")
        XCTAssertTrue(html!.contains("</h2>"), "HTML should contain closing </h2> tag")
        XCTAssertTrue(html!.contains("Subheading"), "HTML should contain the heading text")
    }

    func testHTMLExporterRendersH3() {
        let html = exportHTML("### Third Level")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<h3>"), "HTML should contain <h3> tag for level-3 heading")
        XCTAssertTrue(html!.contains("</h3>"), "HTML should contain closing </h3> tag")
    }

    // MARK: - HTMLExporter: Paragraph Rendering

    func testHTMLExporterRendersParagraph() {
        let html = exportHTML("Some text here")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<p>"), "HTML should contain <p> tag for paragraph")
        XCTAssertTrue(html!.contains("</p>"), "HTML should contain closing </p> tag")
        XCTAssertTrue(html!.contains("Some text here"), "HTML should contain the paragraph text")
    }

    func testHTMLExporterRendersMultipleParagraphs() {
        let html = exportHTML("First paragraph\n\nSecond paragraph")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("First paragraph"), "HTML should contain first paragraph text")
        XCTAssertTrue(html!.contains("Second paragraph"), "HTML should contain second paragraph text")

        // Count occurrences of <p> - should be at least 2
        let pCount = html!.components(separatedBy: "<p>").count - 1
        XCTAssertGreaterThanOrEqual(pCount, 2, "HTML should contain at least 2 paragraph tags")
    }

    // MARK: - HTMLExporter: Code Block Rendering

    func testHTMLExporterRendersCodeBlockAsPreCode() {
        let markdown = """
        ```swift
        let x = 42
        ```
        """
        let html = exportHTML(markdown)
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<pre>"), "HTML should contain <pre> tag for code block")
        XCTAssertTrue(html!.contains("<code"), "HTML should contain <code> tag inside pre for code block")
        XCTAssertTrue(html!.contains("</code>"), "HTML should contain closing </code> tag")
        XCTAssertTrue(html!.contains("</pre>"), "HTML should contain closing </pre> tag")
    }

    func testHTMLExporterRendersCodeBlockLanguageClass() {
        let markdown = """
        ```swift
        let x = 42
        ```
        """
        let html = exportHTML(markdown)
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("language-swift"), "HTML code block should include language class")
    }

    func testHTMLExporterRendersInlineCode() {
        let html = exportHTML("Use `print()` to output")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<code>"), "HTML should contain <code> tag for inline code")
        XCTAssertTrue(html!.contains("print()"), "HTML should contain the inline code text")
    }

    // MARK: - HTMLExporter: Link Rendering

    func testHTMLExporterRendersLinksAsATags() {
        let html = exportHTML("[Example](https://example.com)")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<a "), "HTML should contain <a> tag for links")
        XCTAssertTrue(html!.contains("href=\"https://example.com\""), "HTML link should contain correct href")
        XCTAssertTrue(html!.contains("Example"), "HTML link should contain the link text")
        XCTAssertTrue(html!.contains("</a>"), "HTML should contain closing </a> tag")
    }

    func testHTMLExporterRendersLinkWithTitle() {
        let html = exportHTML("[Example](https://example.com \"A title\")")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("title=\"A title\""), "HTML link should contain the title attribute")
    }

    // MARK: - HTMLExporter: Emphasis and Strong Rendering

    func testHTMLExporterRendersEmphasisAsEm() {
        let html = exportHTML("This is *emphasized* text")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<em>"), "HTML should contain <em> tag for emphasis")
        XCTAssertTrue(html!.contains("emphasized"), "HTML should contain the emphasized text")
        XCTAssertTrue(html!.contains("</em>"), "HTML should contain closing </em> tag")
    }

    func testHTMLExporterRendersStrongAsStrong() {
        let html = exportHTML("This is **bold** text")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<strong>"), "HTML should contain <strong> tag for bold")
        XCTAssertTrue(html!.contains("bold"), "HTML should contain the bold text")
        XCTAssertTrue(html!.contains("</strong>"), "HTML should contain closing </strong> tag")
    }

    func testHTMLExporterRendersStrikethroughAsDel() {
        let html = exportHTML("This is ~~deleted~~ text")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<del>"), "HTML should contain <del> tag for strikethrough")
        XCTAssertTrue(html!.contains("deleted"), "HTML should contain the strikethrough text")
        XCTAssertTrue(html!.contains("</del>"), "HTML should contain closing </del> tag")
    }

    // MARK: - HTMLExporter: HTML Entity Escaping

    func testHTMLExporterEscapesHTMLEntities() {
        let html = exportHTML("Use `<div>` & `\"quotes\"`")
        XCTAssertNotNil(html)
        // The text nodes should have escaped HTML entities
        XCTAssertTrue(html!.contains("&amp;"), "HTML should escape ampersands in text")
    }

    func testHTMLExporterEscapesAngleBracketsInText() {
        let html = exportHTML("Check if a < b and c > d")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("&lt;"), "HTML should escape less-than sign in text")
        XCTAssertTrue(html!.contains("&gt;"), "HTML should escape greater-than sign in text")
    }

    func testHTMLExporterEscapesAngleBracketsInCodeBlocks() {
        let markdown = """
        ```
        <div class="test">
        ```
        """
        let html = exportHTML(markdown)
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("&lt;div"), "HTML should escape angle brackets in code blocks")
    }

    // MARK: - HTMLExporter: Lists

    func testHTMLExporterRendersUnorderedList() {
        let markdown = """
        - Item 1
        - Item 2
        - Item 3
        """
        let html = exportHTML(markdown)
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<ul>"), "HTML should contain <ul> for unordered list")
        XCTAssertTrue(html!.contains("<li>"), "HTML should contain <li> for list items")
        XCTAssertTrue(html!.contains("</ul>"), "HTML should contain closing </ul>")
        XCTAssertTrue(html!.contains("Item 1"), "HTML should contain list item text")
    }

    func testHTMLExporterRendersOrderedList() {
        let markdown = """
        1. First
        2. Second
        3. Third
        """
        let html = exportHTML(markdown)
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<ol>"), "HTML should contain <ol> for ordered list")
        XCTAssertTrue(html!.contains("<li>"), "HTML should contain <li> for list items")
        XCTAssertTrue(html!.contains("</ol>"), "HTML should contain closing </ol>")
    }

    // MARK: - HTMLExporter: Blockquote

    func testHTMLExporterRendersBlockquote() {
        let html = exportHTML("> This is a quote")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<blockquote>"), "HTML should contain <blockquote> tag")
        XCTAssertTrue(html!.contains("This is a quote"), "HTML should contain the quote text")
        XCTAssertTrue(html!.contains("</blockquote>"), "HTML should contain closing </blockquote>")
    }

    // MARK: - HTMLExporter: Thematic Break

    func testHTMLExporterRendersThematicBreak() {
        let html = exportHTML("Above\n\n---\n\nBelow")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<hr>"), "HTML should contain <hr> for thematic break")
    }

    // MARK: - HTMLExporter: Image

    func testHTMLExporterRendersImage() {
        let html = exportHTML("![Alt text](https://example.com/image.png)")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<img "), "HTML should contain <img> tag for images")
        XCTAssertTrue(html!.contains("src=\"https://example.com/image.png\""), "HTML img should have correct src")
        XCTAssertTrue(html!.contains("alt=\"Alt text\""), "HTML img should have correct alt text")
    }

    // MARK: - HTMLExporter: Complex Document

    func testHTMLExporterRendersComplexDocument() {
        let markdown = """
        # Title

        A paragraph with **bold**, *italic*, and `code`.

        ## Section

        - Item one
        - Item two

        > A blockquote

        ```python
        print("hello")
        ```

        [Link](https://example.com)
        """
        let html = exportHTML(markdown)
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<h1>"), "Complex doc should have h1")
        XCTAssertTrue(html!.contains("<h2>"), "Complex doc should have h2")
        XCTAssertTrue(html!.contains("<strong>"), "Complex doc should have strong")
        XCTAssertTrue(html!.contains("<em>"), "Complex doc should have em")
        XCTAssertTrue(html!.contains("<code>"), "Complex doc should have code")
        XCTAssertTrue(html!.contains("<ul>"), "Complex doc should have ul")
        XCTAssertTrue(html!.contains("<blockquote>"), "Complex doc should have blockquote")
        XCTAssertTrue(html!.contains("<pre>"), "Complex doc should have pre")
        XCTAssertTrue(html!.contains("<a "), "Complex doc should have link")
    }

    // MARK: - HTMLExporter: Exporter Protocol Conformance

    func testHTMLExporterConformsToExporterProtocol() {
        let exporter: Exporter = HTMLExporter()
        XCTAssertEqual(exporter.fileExtension, "html")
        XCTAssertEqual(exporter.mimeType, "text/html")

        let document = parseDocument("Hello world")
        let data = exporter.export(document: document, theme: theme)
        XCTAssertNotNil(data)
    }

    // MARK: - RichTextExporter: Properties

    func testRichTextExporterFileExtension() {
        let exporter = RichTextExporter()
        XCTAssertEqual(exporter.fileExtension, "rtf")
    }

    func testRichTextExporterMimeType() {
        let exporter = RichTextExporter()
        XCTAssertEqual(exporter.mimeType, "application/rtf")
    }

    // MARK: - RichTextExporter: Export

    func testRichTextExporterExportsNonNilData() {
        let document = parseDocument("# Hello\n\nSome text")
        let exporter = RichTextExporter()
        let data = exporter.export(document: document, theme: theme)
        XCTAssertNotNil(data, "RTF export should produce non-nil data for a valid document")
    }

    func testRichTextExporterProducesRTFData() {
        let document = parseDocument("# Title\n\nA paragraph.")
        let exporter = RichTextExporter()
        guard let data = exporter.export(document: document, theme: theme) else {
            XCTFail("RTF export should not be nil")
            return
        }
        // RTF files typically start with {\rtf
        let rtfString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
        XCTAssertTrue(rtfString.hasPrefix("{\\rtf"), "RTF data should start with {\\rtf header")
    }

    // MARK: - RichTextExporter: Attributed String

    func testRichTextExporterAttributedStringProducesNonEmptyResult() {
        let document = parseDocument("# Hello\n\nSome text with **bold** and *italic*.")
        let exporter = RichTextExporter()
        let attrString = exporter.attributedString(from: document, theme: theme)
        XCTAssertGreaterThan(attrString.length, 0, "Attributed string should be non-empty")
    }

    func testRichTextExporterAttributedStringContainsHeadingText() {
        let document = parseDocument("# My Heading\n\nBody text")
        let exporter = RichTextExporter()
        let attrString = exporter.attributedString(from: document, theme: theme)
        let plainText = attrString.string
        XCTAssertTrue(plainText.contains("My Heading"), "Attributed string should contain heading text")
        XCTAssertTrue(plainText.contains("Body text"), "Attributed string should contain body text")
    }

    func testRichTextExporterAttributedStringForCodeBlock() {
        let markdown = """
        ```
        let x = 42
        ```
        """
        let document = parseDocument(markdown)
        let exporter = RichTextExporter()
        let attrString = exporter.attributedString(from: document, theme: theme)
        XCTAssertTrue(attrString.string.contains("let x = 42"), "Attributed string should contain code block text")
    }

    func testRichTextExporterConformsToExporterProtocol() {
        let exporter: Exporter = RichTextExporter()
        XCTAssertEqual(exporter.fileExtension, "rtf")
        XCTAssertEqual(exporter.mimeType, "application/rtf")

        let document = parseDocument("Hello world")
        let data = exporter.export(document: document, theme: theme)
        XCTAssertNotNil(data)
    }

    // MARK: - ExportManager: Initialization

    func testExportManagerAvailableFormatsIsNonEmpty() {
        let manager = ExportManager()
        let formats = manager.availableFormats()
        XCTAssertFalse(formats.isEmpty, "ExportManager should have registered formats by default")
    }

    func testExportManagerHasHTMLFormat() {
        let manager = ExportManager()
        let formats = manager.availableFormats()
        XCTAssertTrue(formats.contains("html"), "ExportManager should have html format registered")
    }

    func testExportManagerHasPDFFormat() {
        let manager = ExportManager()
        let formats = manager.availableFormats()
        XCTAssertTrue(formats.contains("pdf"), "ExportManager should have pdf format registered")
    }

    func testExportManagerHasDOCXFormat() {
        let manager = ExportManager()
        let formats = manager.availableFormats()
        XCTAssertTrue(formats.contains("docx"), "ExportManager should have docx format registered")
    }

    func testExportManagerHasRTFFormat() {
        let manager = ExportManager()
        let formats = manager.availableFormats()
        XCTAssertTrue(formats.contains("rtf"), "ExportManager should have rtf format registered")
    }

    func testExportManagerHasAllFourDefaultFormats() {
        let manager = ExportManager()
        let formats = manager.availableFormats()
        let expectedFormats: Set<String> = ["html", "pdf", "docx", "rtf"]
        let actualFormats = Set(formats)
        XCTAssertTrue(expectedFormats.isSubset(of: actualFormats),
                       "ExportManager should contain html, pdf, docx, rtf. Got: \(formats)")
    }

    // MARK: - ExportManager: Export

    func testExportManagerExportReturnsDataForHTMLFormat() {
        let manager = ExportManager()
        let document = parseDocument("# Hello\n\nWorld")
        let data = manager.export(document: document, format: "html", theme: theme)
        XCTAssertNotNil(data, "ExportManager should return data when exporting to html format")
    }

    func testExportManagerExportReturnsDataForPDFFormat() {
        let manager = ExportManager()
        let document = parseDocument("# Hello\n\nWorld")
        let data = manager.export(document: document, format: "pdf", theme: theme)
        XCTAssertNotNil(data, "ExportManager should return data when exporting to pdf format")
    }

    func testExportManagerExportReturnsDataForRTFFormat() {
        let manager = ExportManager()
        let document = parseDocument("# Hello\n\nWorld")
        let data = manager.export(document: document, format: "rtf", theme: theme)
        XCTAssertNotNil(data, "ExportManager should return data when exporting to rtf format")
    }

    func testExportManagerExportReturnsDataForDOCXFormat() {
        let manager = ExportManager()
        let document = parseDocument("# Hello\n\nWorld")
        let data = manager.export(document: document, format: "docx", theme: theme)
        XCTAssertNotNil(data, "ExportManager should return data when exporting to docx format")
    }

    func testExportManagerExportReturnsNilForUnknownFormat() {
        let manager = ExportManager()
        let document = parseDocument("# Hello\n\nWorld")
        let data = manager.export(document: document, format: "xyz", theme: theme)
        XCTAssertNil(data, "ExportManager should return nil for an unregistered format")
    }

    func testExportManagerExportReturnsNilForEmptyFormat() {
        let manager = ExportManager()
        let document = parseDocument("Some text")
        let data = manager.export(document: document, format: "", theme: theme)
        XCTAssertNil(data, "ExportManager should return nil for an empty format string")
    }

    // MARK: - ExportManager: exporter(for:)

    func testExportManagerExporterForHTMLReturnsHTMLExporter() {
        let manager = ExportManager()
        let exporter = manager.exporter(for: "html")
        XCTAssertNotNil(exporter, "ExportManager should return an exporter for html")
        XCTAssertTrue(exporter is HTMLExporter, "Exporter for html should be an HTMLExporter instance")
    }

    func testExportManagerExporterForPDFReturnsPDFExporter() {
        let manager = ExportManager()
        let exporter = manager.exporter(for: "pdf")
        XCTAssertNotNil(exporter, "ExportManager should return an exporter for pdf")
        XCTAssertTrue(exporter is PDFExporter, "Exporter for pdf should be a PDFExporter instance")
    }

    func testExportManagerExporterForDOCXReturnsDOCXExporter() {
        let manager = ExportManager()
        let exporter = manager.exporter(for: "docx")
        XCTAssertNotNil(exporter, "ExportManager should return an exporter for docx")
        XCTAssertTrue(exporter is DOCXExporter, "Exporter for docx should be a DOCXExporter instance")
    }

    func testExportManagerExporterForRTFReturnsRichTextExporter() {
        let manager = ExportManager()
        let exporter = manager.exporter(for: "rtf")
        XCTAssertNotNil(exporter, "ExportManager should return an exporter for rtf")
        XCTAssertTrue(exporter is RichTextExporter, "Exporter for rtf should be a RichTextExporter instance")
    }

    func testExportManagerExporterForUnknownFormatReturnsNil() {
        let manager = ExportManager()
        let exporter = manager.exporter(for: "unknown")
        XCTAssertNil(exporter, "ExportManager should return nil for an unregistered format")
    }

    // MARK: - ExportManager: Register Custom Exporter

    func testExportManagerRegisterCustomExporter() {
        let manager = ExportManager()
        let custom = StubExporter(ext: "txt", mime: "text/plain")
        manager.register(custom)

        let formats = manager.availableFormats()
        XCTAssertTrue(formats.contains("txt"), "After registering a custom exporter, its format should appear in availableFormats")

        let retrieved = manager.exporter(for: "txt")
        XCTAssertNotNil(retrieved, "Custom exporter should be retrievable by its file extension")
        XCTAssertTrue(retrieved is StubExporter, "Retrieved exporter should be the registered custom type")
    }

    func testExportManagerRegisterCustomExporterCanExport() {
        let manager = ExportManager()
        let custom = StubExporter(ext: "txt", mime: "text/plain")
        manager.register(custom)

        let document = parseDocument("Hello")
        let data = manager.export(document: document, format: "txt", theme: theme)
        XCTAssertNotNil(data, "Custom exporter should be able to export via ExportManager")
    }

    func testExportManagerRegisterOverridesExistingFormat() {
        let manager = ExportManager()
        let custom = StubExporter(ext: "html", mime: "text/html")
        manager.register(custom)

        let exporter = manager.exporter(for: "html")
        XCTAssertTrue(exporter is StubExporter,
                       "Registering a new exporter for an existing format should override the previous one")
    }

    // MARK: - ExportManager: Available Formats Sorted

    func testExportManagerAvailableFormatsAreSorted() {
        let manager = ExportManager()
        let formats = manager.availableFormats()
        let sorted = formats.sorted()
        XCTAssertEqual(formats, sorted, "availableFormats() should return formats in sorted order")
    }

    // MARK: - HTMLExporter: Empty Document

    func testHTMLExporterHandlesEmptyDocument() {
        let document = parseDocument("")
        let exporter = HTMLExporter()
        let data = exporter.export(document: document, theme: theme)
        XCTAssertNotNil(data, "HTML export should produce data even for an empty document")

        if let html = data.flatMap({ String(data: $0, encoding: .utf8) }) {
            XCTAssertTrue(html.contains("<!DOCTYPE html>"), "Even empty document should produce valid HTML structure")
        }
    }

    // MARK: - HTMLExporter: Table Rendering

    func testHTMLExporterRendersTable() {
        let markdown = """
        | Header 1 | Header 2 |
        | -------- | -------- |
        | Cell 1   | Cell 2   |
        """
        let html = exportHTML(markdown)
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<table>"), "HTML should contain <table> tag")
        XCTAssertTrue(html!.contains("<th>"), "HTML should contain <th> for header cells")
        XCTAssertTrue(html!.contains("<td>"), "HTML should contain <td> for body cells")
        XCTAssertTrue(html!.contains("</table>"), "HTML should contain closing </table>")
    }

    // MARK: - HTMLExporter: Meta Tags

    func testHTMLExporterIncludesMetaCharset() {
        let html = exportHTML("Hello")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("charset=\"UTF-8\"") || html!.contains("charset=UTF-8"),
                       "HTML should include UTF-8 charset meta tag")
    }

    func testHTMLExporterIncludesViewportMeta() {
        let html = exportHTML("Hello")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("viewport"), "HTML should include viewport meta tag")
    }

    // MARK: - HTMLExporter: Article Wrapper

    func testHTMLExporterWrapsContentInArticle() {
        let html = exportHTML("Hello")
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<article"), "HTML should wrap content in an article element")
        XCTAssertTrue(html!.contains("markdown-body"), "HTML article should have markdown-body class")
        XCTAssertTrue(html!.contains("</article>"), "HTML should contain closing article tag")
    }
}

// MARK: - Test Helpers

/// A minimal stub exporter used for testing custom exporter registration.
private final class StubExporter: Exporter {
    let fileExtension: String
    let mimeType: String

    init(ext: String, mime: String) {
        self.fileExtension = ext
        self.mimeType = mime
    }

    func export(document: TymarkParser.TymarkDocument, theme: Theme) -> Data? {
        // Return a simple data representation for testing purposes
        return "stub-export".data(using: .utf8)
    }
}

#endif
