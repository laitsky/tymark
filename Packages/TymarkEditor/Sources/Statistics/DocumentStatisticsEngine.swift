import Foundation

// MARK: - Document Statistics

public struct DocumentStatistics: Equatable, Sendable {
    public var wordCount: Int
    public var characterCount: Int
    public var characterCountNoSpaces: Int
    public var sentenceCount: Int
    public var paragraphCount: Int
    public var readingTimeMinutes: Double  // 250 WPM average
    public var lineCount: Int

    public init(
        wordCount: Int = 0,
        characterCount: Int = 0,
        characterCountNoSpaces: Int = 0,
        sentenceCount: Int = 0,
        paragraphCount: Int = 0,
        readingTimeMinutes: Double = 0,
        lineCount: Int = 0
    ) {
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.characterCountNoSpaces = characterCountNoSpaces
        self.sentenceCount = sentenceCount
        self.paragraphCount = paragraphCount
        self.readingTimeMinutes = readingTimeMinutes
        self.lineCount = lineCount
    }
}

// MARK: - Statistics Engine

public enum DocumentStatisticsEngine {

    /// Compute document statistics from raw text.
    public static func compute(from text: String) -> DocumentStatistics {
        guard !text.isEmpty else { return DocumentStatistics() }

        let nsText = text as NSString

        // Character counts
        let characterCount = nsText.length
        let characterCountNoSpaces = text.filter { !$0.isWhitespace }.count

        // Word count
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let wordCount = words.count

        // Sentence count (split on sentence-ending punctuation)
        let sentencePattern = "[.!?]+[\\s\\n]|[.!?]+$"
        let sentenceRegex = try? NSRegularExpression(pattern: sentencePattern)
        let sentenceCount = max(1, sentenceRegex?.numberOfMatches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ) ?? 1)

        // Paragraph count (separated by blank lines)
        let paragraphs = text.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let paragraphCount = max(1, paragraphs.count)

        // Line count
        let lineCount = text.components(separatedBy: "\n").count

        // Reading time (250 words per minute average)
        let readingTimeMinutes = Double(wordCount) / 250.0

        return DocumentStatistics(
            wordCount: wordCount,
            characterCount: characterCount,
            characterCountNoSpaces: characterCountNoSpaces,
            sentenceCount: sentenceCount,
            paragraphCount: paragraphCount,
            readingTimeMinutes: readingTimeMinutes,
            lineCount: lineCount
        )
    }
}
