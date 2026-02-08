import Foundation
import TymarkParser
import TymarkTheme

// MARK: - DOCX Exporter

/// Generates Microsoft Word .docx files from the markdown AST.
/// Creates a valid Open XML document with proper structure, styles, and content.
public final class DOCXExporter: Exporter {
    public let fileExtension = "docx"
    public let mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

    /// Collected hyperlinks during document conversion.
    /// Each entry maps a relationship ID (e.g. "rId10") to a URL string.
    private var hyperlinks: [(id: String, url: String)] = []
    private var nextHyperlinkId = 10 // Start after rId1 (styles)

    public init() {}

    // MARK: - Exporter Protocol

    public func export(document: TymarkParser.TymarkDocument, theme: Theme) -> Data? {
        // Reset hyperlink tracking for each export
        hyperlinks = []
        nextHyperlinkId = 10

        let archiver = ZIPArchiver()

        // Generate document XML first so hyperlinks are collected
        let docXML = documentXML(root: document.root, theme: theme)

        // Add required DOCX structure files
        archiver.addEntry(path: "[Content_Types].xml", content: contentTypesXML())
        archiver.addEntry(path: "_rels/.rels", content: relsXML())
        archiver.addEntry(path: "word/_rels/document.xml.rels", content: documentRelsXML())
        archiver.addEntry(path: "word/styles.xml", content: stylesXML(theme: theme))
        archiver.addEntry(path: "word/document.xml", content: docXML)

        return archiver.build()
    }

    // MARK: - Content Types

    private func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
            <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
        </Types>
        """
    }

    // MARK: - Relationships

    private func relsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
    }

    private func documentRelsXML() -> String {
        var rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        """
        for link in hyperlinks {
            rels += "\n    <Relationship Id=\"\(link.id)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"\(escapeXML(link.url))\" TargetMode=\"External\"/>"
        }
        rels += "\n</Relationships>"
        return rels
    }

    // MARK: - Styles

    private func stylesXML(theme: Theme) -> String {
        let bodyFontSize = Int(theme.fonts.body.size * 2) // half-points
        let codeFontSize = Int(theme.fonts.code.size * 2)
        let bodyFontFamily = theme.fonts.body.family
        let codeFontFamily = theme.fonts.code.family
        let textColor = colorToHex(theme.colors.text)
        let headingColor = colorToHex(theme.colors.heading)
        let quoteColor = colorToHex(theme.colors.quoteText)
        let codeColor = colorToHex(theme.colors.codeText)
        let codeBgColor = colorToHex(theme.colors.codeBackground)

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:docDefaults>
                <w:rPrDefault>
                    <w:rPr>
                        <w:rFonts w:ascii="\(escapeXML(bodyFontFamily))" w:hAnsi="\(escapeXML(bodyFontFamily))"/>
                        <w:sz w:val="\(bodyFontSize)"/>
                        <w:color w:val="\(textColor)"/>
                    </w:rPr>
                </w:rPrDefault>
                <w:pPrDefault>
                    <w:pPr>
                        <w:spacing w:after="\(Int(theme.spacing.paragraphSpacing * 20))" w:line="\(Int(theme.spacing.lineHeight * 240))"/>
                    </w:pPr>
                </w:pPrDefault>
            </w:docDefaults>
            <w:style w:type="paragraph" w:styleId="Normal">
                <w:name w:val="Normal"/>
                <w:qFormat/>
            </w:style>
            \(headingStyles(headingColor: headingColor, bodyFontFamily: bodyFontFamily, bodyFontSize: bodyFontSize))
            <w:style w:type="paragraph" w:styleId="Quote">
                <w:name w:val="Quote"/>
                <w:basedOn w:val="Normal"/>
                <w:pPr>
                    <w:ind w:left="720"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="12" w:space="8" w:color="CCCCCC"/>
                    </w:pBdr>
                </w:pPr>
                <w:rPr>
                    <w:i/>
                    <w:color w:val="\(quoteColor)"/>
                </w:rPr>
            </w:style>
            <w:style w:type="character" w:styleId="CodeChar">
                <w:name w:val="Code Char"/>
                <w:rPr>
                    <w:rFonts w:ascii="\(escapeXML(codeFontFamily))" w:hAnsi="\(escapeXML(codeFontFamily))"/>
                    <w:sz w:val="\(codeFontSize)"/>
                    <w:color w:val="\(codeColor)"/>
                    <w:shd w:val="clear" w:color="auto" w:fill="\(codeBgColor)"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="CodeBlock">
                <w:name w:val="Code Block"/>
                <w:basedOn w:val="Normal"/>
                <w:pPr>
                    <w:shd w:val="clear" w:color="auto" w:fill="\(codeBgColor)"/>
                    <w:spacing w:before="120" w:after="120"/>
                    <w:ind w:left="240" w:right="240"/>
                </w:pPr>
                <w:rPr>
                    <w:rFonts w:ascii="\(escapeXML(codeFontFamily))" w:hAnsi="\(escapeXML(codeFontFamily))"/>
                    <w:sz w:val="\(codeFontSize)"/>
                    <w:color w:val="\(codeColor)"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="ListParagraph">
                <w:name w:val="List Paragraph"/>
                <w:basedOn w:val="Normal"/>
                <w:pPr>
                    <w:ind w:left="720"/>
                </w:pPr>
            </w:style>
        </w:styles>
        """
    }

    private func headingStyles(headingColor: String, bodyFontFamily: String, bodyFontSize: Int) -> String {
        let headingConfigs: [(id: Int, name: String, sizeMultiplier: Double)] = [
            (1, "heading 1", 2.0),
            (2, "heading 2", 1.5),
            (3, "heading 3", 1.25),
            (4, "heading 4", 1.1),
            (5, "heading 5", 1.0),
            (6, "heading 6", 0.9)
        ]

        return headingConfigs.map { config in
            let fontSize = Int(Double(bodyFontSize) * config.sizeMultiplier)
            return """
            <w:style w:type="paragraph" w:styleId="Heading\(config.id)">
                <w:name w:val="\(config.name)"/>
                <w:basedOn w:val="Normal"/>
                <w:qFormat/>
                <w:pPr>
                    <w:spacing w:before="360" w:after="120"/>
                    <w:keepNext/>
                </w:pPr>
                <w:rPr>
                    <w:rFonts w:ascii="\(escapeXML(bodyFontFamily))" w:hAnsi="\(escapeXML(bodyFontFamily))"/>
                    <w:b/>
                    <w:sz w:val="\(fontSize)"/>
                    <w:color w:val="\(headingColor)"/>
                </w:rPr>
            </w:style>
            """
        }.joined(separator: "\n")
    }

    // MARK: - Document Body

    private func documentXML(root: TymarkNode, theme: Theme) -> String {
        var body = ""
        for child in root.children {
            body += convertNode(child, theme: theme, depth: 0)
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <w:body>
                \(body)
                <w:sectPr>
                    <w:pgSz w:w="12240" w:h="15840"/>
                    <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
                </w:sectPr>
            </w:body>
        </w:document>
        """
    }

    // MARK: - Node Conversion

    private func convertNode(_ node: TymarkNode, theme: Theme, depth: Int) -> String {
        switch node.type {
        case .document:
            return node.children.map { convertNode($0, theme: theme, depth: depth) }.joined()

        case .paragraph:
            let runs = node.children.map { convertInlineNode($0, theme: theme) }.joined()
            return paragraph(runs: runs)

        case .heading(let level):
            let runs = node.children.map { convertInlineNode($0, theme: theme) }.joined()
            return paragraph(runs: runs, style: "Heading\(min(level, 6))")

        case .blockquote:
            return node.children.map { child -> String in
                if case .paragraph = child.type {
                    let runs = child.children.map { convertInlineNode($0, theme: theme) }.joined()
                    return paragraph(runs: runs, style: "Quote")
                }
                return convertNode(child, theme: theme, depth: depth)
            }.joined()

        case .codeBlock:
            let lines = node.content.components(separatedBy: "\n")
            return lines.map { line in
                let run = textRun(escapeXML(line))
                return paragraph(runs: run, style: "CodeBlock")
            }.joined()

        case .list(let ordered):
            return node.children.enumerated().map { index, child in
                convertListItem(child, ordered: ordered, index: index + 1, depth: depth, theme: theme)
            }.joined()

        case .listItem:
            return node.children.map { convertNode($0, theme: theme, depth: depth) }.joined()

        case .thematicBreak:
            return """
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:bottom w:val="single" w:sz="6" w:space="1" w:color="auto"/>
                    </w:pBdr>
                </w:pPr>
            </w:p>
            """

        case .table:
            return convertTable(node, theme: theme)

        default:
            return node.children.map { convertNode($0, theme: theme, depth: depth) }.joined()
        }
    }

    private func convertListItem(_ node: TymarkNode, ordered: Bool, index: Int, depth: Int, theme: Theme) -> String {
        let bullet = ordered ? "\(index)." : "\u{2022}"

        return node.children.map { child -> String in
            if case .paragraph = child.type {
                let bulletRun = textRun("\(bullet) ")
                let contentRuns = child.children.map { convertInlineNode($0, theme: theme) }.joined()
                return paragraph(runs: bulletRun + contentRuns, style: "ListParagraph", indentLevel: depth)
            }
            return convertNode(child, theme: theme, depth: depth + 1)
        }.joined()
    }

    private func convertTable(_ node: TymarkNode, theme: Theme) -> String {
        var xml = "<w:tbl>"
        xml += """
        <w:tblPr>
            <w:tblBorders>
                <w:top w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
                <w:left w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
                <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
                <w:right w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
                <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
                <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
            </w:tblBorders>
            <w:tblW w:w="0" w:type="auto"/>
        </w:tblPr>
        """

        for (rowIndex, row) in node.children.enumerated() {
            guard case .tableRow = row.type else { continue }

            xml += "<w:tr>"
            for cell in row.children {
                xml += "<w:tc>"

                // Bold header cells
                if rowIndex == 0 {
                    let runs = cell.children.map { convertInlineNode($0, theme: theme, bold: true) }.joined()
                    xml += paragraph(runs: runs)
                } else {
                    let runs = cell.children.map { convertInlineNode($0, theme: theme) }.joined()
                    xml += paragraph(runs: runs)
                }

                xml += "</w:tc>"
            }
            xml += "</w:tr>"
        }

        xml += "</w:tbl>"
        return xml
    }

    // MARK: - Inline Node Conversion

    private func convertInlineNode(_ node: TymarkNode, theme: Theme, bold: Bool = false, italic: Bool = false) -> String {
        switch node.type {
        case .text:
            return textRun(escapeXML(node.content), bold: bold, italic: italic)

        case .emphasis:
            return node.children.map { convertInlineNode($0, theme: theme, bold: bold, italic: true) }.joined()

        case .strong:
            return node.children.map { convertInlineNode($0, theme: theme, bold: true, italic: italic) }.joined()

        case .inlineCode:
            return """
            <w:r>
                <w:rPr><w:rStyle w:val="CodeChar"/></w:rPr>
                <w:t xml:space="preserve">\(escapeXML(node.content))</w:t>
            </w:r>
            """

        case .link(let destination, _):
            let linkColor = colorToHex(theme.colors.link)
            let rId = registerHyperlink(url: destination)
            return """
            <w:hyperlink r:id="\(rId)">
                <w:r>
                    <w:rPr>
                        <w:color w:val="\(linkColor)"/>
                        <w:u w:val="single"/>
                    </w:rPr>
                    <w:t xml:space="preserve">\(escapeXML(node.children.first?.content ?? destination))</w:t>
                </w:r>
            </w:hyperlink>
            """

        case .image(_, let alt):
            return textRun(escapeXML("[\(alt ?? "image")]"), italic: true)

        case .strikethrough:
            return node.children.map { child -> String in
                if case .text = child.type {
                    return """
                    <w:r>
                        <w:rPr><w:strike/></w:rPr>
                        <w:t xml:space="preserve">\(escapeXML(child.content))</w:t>
                    </w:r>
                    """
                }
                return convertInlineNode(child, theme: theme)
            }.joined()

        case .softBreak:
            return textRun(" ")

        case .lineBreak:
            return "<w:r><w:br/></w:r>"

        default:
            return node.children.map { convertInlineNode($0, theme: theme) }.joined()
        }
    }

    // MARK: - XML Helpers

    private func textRun(_ text: String, bold: Bool = false, italic: Bool = false) -> String {
        var rPr = ""
        if bold || italic {
            rPr = "<w:rPr>"
            if bold { rPr += "<w:b/>" }
            if italic { rPr += "<w:i/>" }
            rPr += "</w:rPr>"
        }
        return """
        <w:r>\(rPr)<w:t xml:space="preserve">\(text)</w:t></w:r>
        """
    }

    private func paragraph(runs: String, style: String? = nil, indentLevel: Int = 0) -> String {
        var pPr = ""
        if style != nil || indentLevel > 0 {
            pPr = "<w:pPr>"
            if let style {
                pPr += "<w:pStyle w:val=\"\(style)\"/>"
            }
            if indentLevel > 0 {
                pPr += "<w:ind w:left=\"\(indentLevel * 720)\"/>"
            }
            pPr += "</w:pPr>"
        }
        return "<w:p>\(pPr)\(runs)</w:p>\n"
    }

    private func registerHyperlink(url: String) -> String {
        let rId = "rId\(nextHyperlinkId)"
        nextHyperlinkId += 1
        hyperlinks.append((id: rId, url: url))
        return rId
    }

    private func escapeXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func colorToHex(_ color: CodableColor) -> String {
        let r = Int(max(0, min(255, color.red * 255)))
        let g = Int(max(0, min(255, color.green * 255)))
        let b = Int(max(0, min(255, color.blue * 255)))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
