import Foundation

// MARK: - Search Result

public struct SearchResult: Identifiable, Comparable {
    public let id = UUID()
    public let file: WorkspaceFile
    public let score: Double
    public let matchedRanges: [NSRange]

    public static func < (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return lhs.score > rhs.score // Higher score first
    }

    public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return lhs.file.id == rhs.file.id &&
               lhs.score == rhs.score
    }
}

// MARK: - Fuzzy Search Engine

public final class FuzzySearchEngine {

    // MARK: - Properties

    private var files: [WorkspaceFile] = []
    private var fileContents: [UUID: String] = [:]

    // MARK: - Configuration

    public struct Configuration {
        var caseSensitive: Bool
        var maxResults: Int
        var minScore: Double
        var searchContent: Bool

        public static let `default` = Configuration(
            caseSensitive: false,
            maxResults: 50,
            minScore: 0.3,
            searchContent: true
        )
    }

    private let config: Configuration

    // MARK: - Initialization

    public init(configuration: Configuration = .default) {
        self.config = configuration
    }

    // MARK: - Public API

    public func index(_ files: [WorkspaceFile]) {
        self.files = flatten(files)
    }

    public func search(query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []

        for file in files {
            let (score, ranges) = match(query: query, against: file.name)

            if score >= config.minScore {
                results.append(SearchResult(file: file, score: score, matchedRanges: ranges))
            }
        }

        // Sort by score descending
        results.sort()

        // Limit results
        return Array(results.prefix(config.maxResults))
    }

    public func quickOpen(query: String) -> [SearchResult] {
        // Optimized for real-time quick open
        // Uses a simplified matching algorithm

        guard !query.isEmpty else { return [] }

        let normalizedQuery = config.caseSensitive ? query : query.lowercased()
        let queryChars = Array(normalizedQuery)

        var results: [SearchResult] = []

        for file in files {
            let fileName = config.caseSensitive ? file.name : file.name.lowercased()

            if let score = quickMatch(queryChars: queryChars, fileName: fileName) {
                results.append(SearchResult(
                    file: file,
                    score: score,
                    matchedRanges: []
                ))
            }
        }

        results.sort()
        return Array(results.prefix(config.maxResults))
    }

    // MARK: - Private Methods

    private func flatten(_ files: [WorkspaceFile]) -> [WorkspaceFile] {
        var result: [WorkspaceFile] = []

        for file in files {
            result.append(file)
            if file.isDirectory && !file.children.isEmpty {
                result.append(contentsOf: flatten(file.children))
            }
        }

        return result
    }

    private func match(query: String, against text: String) -> (score: Double, ranges: [NSRange]) {
        let normalizedQuery = config.caseSensitive ? query : query.lowercased()
        let normalizedText = config.caseSensitive ? text : text.lowercased()

        var score: Double = 0
        var ranges: [NSRange] = []

        // Exact match bonus
        if normalizedText == normalizedQuery {
            score = 1.0
            ranges = [NSRange(location: 0, length: text.count)]
            return (score, ranges)
        }

        // Contains exact substring
        if let range = normalizedText.range(of: normalizedQuery) {
            let lowerBound = normalizedText.distance(from: normalizedText.startIndex, to: range.lowerBound)
            let upperBound = normalizedText.distance(from: normalizedText.startIndex, to: range.upperBound)
            let nsRange = NSRange(location: lowerBound, length: upperBound - lowerBound)

            score = 0.8

            // Bonus for matching at start
            if lowerBound == 0 {
                score += 0.1
            }

            // Bonus for matching filename only (not path)
            if !normalizedText.contains("/") {
                score += 0.05
            }

            ranges = [nsRange]
            return (score, ranges)
        }

        // Fuzzy match
        let (fuzzyScore, fuzzyRanges) = fuzzyMatch(query: normalizedQuery, text: normalizedText)
        score = fuzzyScore

        // Convert ranges
        ranges = fuzzyRanges.map { NSRange(location: $0.start, length: $0.end - $0.start) }

        return (score, ranges)
    }

    private func fuzzyMatch(query: String, text: String) -> (score: Double, ranges: [(start: Int, end: Int)]) {
        let queryChars = Array(query)
        let textChars = Array(text)

        var queryIndex = 0
        var textIndex = 0
        var ranges: [(start: Int, end: Int)] = []
        var currentRangeStart: Int? = nil
        var matches = 0
        var consecutiveMatches = 0
        var maxConsecutive = 0

        while queryIndex < queryChars.count && textIndex < textChars.count {
            if queryChars[queryIndex] == textChars[textIndex] {
                if currentRangeStart == nil {
                    currentRangeStart = textIndex
                }
                consecutiveMatches += 1
                maxConsecutive = max(maxConsecutive, consecutiveMatches)
                queryIndex += 1
                matches += 1
            } else {
                if let start = currentRangeStart {
                    ranges.append((start: start, end: textIndex))
                    currentRangeStart = nil
                }
                consecutiveMatches = 0
            }
            textIndex += 1
        }

        // Close final range
        if let start = currentRangeStart {
            ranges.append((start: start, end: textIndex))
        }

        // Calculate score
        guard matches == queryChars.count else {
            return (0, [])
        }

        var score = Double(matches) / Double(queryChars.count)

        // Bonus for consecutive matches
        score += Double(maxConsecutive) * 0.1

        // Penalty for longer text
        score *= Double(queryChars.count) / Double(textChars.count)

        // Bonus for matches at word boundaries
        for range in ranges {
            if range.start == 0 || textChars[range.start - 1] == " " || textChars[range.start - 1] == "/" {
                score += 0.1
            }
        }

        return (min(score, 1.0), ranges)
    }

    private func quickMatch(queryChars: [Character], fileName: String) -> Double? {
        let fileNameChars = Array(fileName)
        var queryIndex = 0
        var fileIndex = 0
        var matches = 0
        var consecutive = 0
        var maxConsecutive = 0

        while queryIndex < queryChars.count && fileIndex < fileNameChars.count {
            if queryChars[queryIndex] == fileNameChars[fileIndex] {
                queryIndex += 1
                matches += 1
                consecutive += 1
                maxConsecutive = max(maxConsecutive, consecutive)
            } else {
                consecutive = 0
            }
            fileIndex += 1
        }

        guard queryIndex == queryChars.count else { return nil }

        var score = Double(matches) / Double(queryChars.count)
        score += Double(maxConsecutive) * 0.05
        score *= Double(queryChars.count) / Double(fileNameChars.count)

        return min(score, 1.0)
    }
}

// MARK: - File Outline Provider

public final class FileOutlineProvider {

    public struct OutlineItem: Identifiable {
        public let id = UUID()
        public let title: String
        public let level: Int
        public let range: NSRange
        public let type: OutlineItemType
    }

    public enum OutlineItemType {
        case heading(level: Int)
        case section
        case bookmark
    }

    public static func generateOutline(from source: String) -> [OutlineItem] {
        var items: [OutlineItem] = []
        let nsSource = source as NSString

        // Pre-compute line start offsets to avoid O(n^2)
        var lineStartOffsets: [Int] = [0]
        for i in 0..<nsSource.length {
            if nsSource.character(at: i) == 0x0A { // \n
                lineStartOffsets.append(i + 1)
            }
        }

        let lines = source.components(separatedBy: "\n")

        for (lineNumber, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for headings
            guard trimmed.hasPrefix("#") else { continue }

            let level = trimmed.prefix { $0 == "#" }.count
            guard level >= 1 && level <= 6 else { continue }

            // Get the title (drop the #s and the space after them)
            let afterHashes = trimmed.dropFirst(level)
            let title = afterHashes.hasPrefix(" ") ? String(afterHashes.dropFirst()) : String(afterHashes)

            // Use pre-computed offset
            let location = lineNumber < lineStartOffsets.count ? lineStartOffsets[lineNumber] : 0
            let length = (line as NSString).length

            items.append(OutlineItem(
                title: title,
                level: level,
                range: NSRange(location: location, length: length),
                type: .heading(level: level)
            ))
        }

        return items
    }
}
