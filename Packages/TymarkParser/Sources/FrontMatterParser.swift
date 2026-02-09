import Foundation

// MARK: - Front Matter

/// Represents YAML front matter at the top of a markdown document.
public struct FrontMatter: Equatable, Sendable {
    /// The raw YAML content between the --- delimiters.
    public let raw: String
    /// Simple key-value pairs extracted from the YAML.
    public let fields: [String: String]
    /// The range in the source text (including delimiters).
    public let range: NSRange

    public init(raw: String, fields: [String: String], range: NSRange) {
        self.raw = raw
        self.fields = fields
        self.range = range
    }
}

// MARK: - Front Matter Parser

public enum FrontMatterParser {

    /// Extracts front matter from the beginning of a document.
    /// Returns the front matter and the remaining source text.
    public static func extract(from source: String) -> (frontMatter: FrontMatter?, strippedSource: String) {
        let nsSource = source as NSString

        // Must start with --- on the first line
        guard nsSource.length >= 3 && nsSource.substring(to: 3) == "---" else {
            return (nil, source)
        }

        // Check that the first line is exactly "---" (possibly with trailing whitespace)
        let firstLineEnd = nsSource.range(of: "\n").location
        guard firstLineEnd != NSNotFound else { return (nil, source) }

        let firstLine = nsSource.substring(to: firstLineEnd).trimmingCharacters(in: .whitespaces)
        guard firstLine == "---" else { return (nil, source) }

        // Find closing ---
        let afterFirst = firstLineEnd + 1
        let searchRange = NSRange(location: afterFirst, length: nsSource.length - afterFirst)
        let closingPattern = try? NSRegularExpression(pattern: "^---\\s*$", options: .anchorsMatchLines)
        guard let match = closingPattern?.firstMatch(in: source, range: searchRange) else {
            return (nil, source)
        }

        let closingRange = match.range
        let closingEnd = NSMaxRange(closingRange)

        // Extract YAML content between delimiters
        let yamlRange = NSRange(location: afterFirst, length: closingRange.location - afterFirst)
        let yamlContent = nsSource.substring(with: yamlRange)

        // Parse simple key-value pairs
        let fields = parseSimpleYAML(yamlContent)

        // Full range including delimiters and trailing newline if present
        let endIncludingNewline: Int
        if closingEnd < nsSource.length && nsSource.character(at: closingEnd) == UInt16(Character("\n").asciiValue!) {
            endIncludingNewline = closingEnd + 1
        } else {
            endIncludingNewline = closingEnd
        }
        let fullRange = NSRange(location: 0, length: min(endIncludingNewline, nsSource.length))
        let frontMatter = FrontMatter(raw: yamlContent, fields: fields, range: fullRange)

        // Stripped source (skip the front matter)
        let strippedStart = min(endIncludingNewline, nsSource.length)
        let stripped = nsSource.substring(from: strippedStart)

        return (frontMatter, stripped)
    }

    /// Parses simple YAML key-value pairs (no nesting, no arrays).
    private static func parseSimpleYAML(_ yaml: String) -> [String: String] {
        var fields: [String: String] = [:]

        for line in yaml.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { continue }

            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[trimmed.startIndex..<colonIndex])
                    .trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                if !key.isEmpty {
                    fields[key] = value
                }
            }
        }

        return fields
    }
}
