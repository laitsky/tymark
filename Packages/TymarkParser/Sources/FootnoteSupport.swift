import Foundation

// MARK: - Footnote Support

/// Post-processing pass that scans for footnote references [^id] and
/// definitions [^id]: content, injecting them as nodes into the AST.
public enum FootnoteSupport {

    /// Scans the source text for footnote patterns and returns additional nodes to merge.
    public static func extractFootnotes(from source: String) -> (references: [TymarkNode], definitions: [TymarkNode]) {
        let nsSource = source as NSString
        var references: [TymarkNode] = []
        var definitions: [TymarkNode] = []

        // Match footnote references: [^identifier]
        // Must not be followed by : (which would be a definition)
        let refPattern = try? NSRegularExpression(pattern: "\\[\\^([^\\]]+)\\](?!:)", options: [])
        let refMatches = refPattern?.matches(in: source, range: NSRange(location: 0, length: nsSource.length)) ?? []

        for match in refMatches {
            let fullRange = match.range
            let idRange = match.range(at: 1)
            let id = nsSource.substring(with: idRange)

            references.append(TymarkNode(
                type: .footnoteReference(id: id),
                content: nsSource.substring(with: fullRange),
                range: fullRange
            ))
        }

        // Match footnote definitions: [^identifier]: content
        // These appear at the start of a line
        let defPattern = try? NSRegularExpression(
            pattern: "^\\[\\^([^\\]]+)\\]:\\s*(.+)$",
            options: .anchorsMatchLines
        )
        let defMatches = defPattern?.matches(in: source, range: NSRange(location: 0, length: nsSource.length)) ?? []

        for match in defMatches {
            let fullRange = match.range
            let idRange = match.range(at: 1)
            let id = nsSource.substring(with: idRange)
            let content = match.range(at: 2).location != NSNotFound
                ? nsSource.substring(with: match.range(at: 2))
                : ""

            definitions.append(TymarkNode(
                type: .footnoteDefinition(id: id),
                content: content,
                range: fullRange
            ))
        }

        return (references, definitions)
    }
}
