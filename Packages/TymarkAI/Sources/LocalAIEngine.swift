import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

// MARK: - Local AI Engine

/// Baseline local AI engine using NLTagger and NSSpellChecker for text processing.
/// Future enhancement: Core ML model integration for more sophisticated processing.
public final class LocalAIEngine: AIServiceProtocol, @unchecked Sendable {

    public let engineType: AIEngineType = .local
    private let _isCancelled = LockedValue(false)
    private var currentTask: Task<Void, Never>?

    public init() {}

    public var isAvailable: Bool {
        return true // Local engine is always available
    }

    public func process(_ request: AIRequest) -> AsyncThrowingStream<AIResponse, Error> {
        _isCancelled.set(false)

        return AsyncThrowingStream { continuation in
            let task = Task.detached { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }

                do {
                    let result = try await self.processLocally(request)

                    guard !self._isCancelled.get() else {
                        continuation.finish()
                        return
                    }

                    // Simulate streaming by sending chunks
                    let words = result.components(separatedBy: " ")
                    var accumulated = ""

                    for (index, word) in words.enumerated() {
                        guard !Task.isCancelled && !self._isCancelled.get() else {
                            continuation.finish()
                            return
                        }

                        accumulated += (index > 0 ? " " : "") + word
                        continuation.yield(AIResponse(type: .partial(text: accumulated)))

                        // Small delay to simulate streaming
                        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
                    }

                    continuation.yield(AIResponse(type: .complete(text: accumulated)))
                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        continuation.yield(AIResponse(type: .error(message: error.localizedDescription)))
                    }
                    continuation.finish()
                }
            }
            self.currentTask = task
        }
    }

    public func cancel() {
        _isCancelled.set(true)
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Local Processing

    private func processLocally(_ request: AIRequest) async throws -> String {
        switch request.taskType {
        case .fixGrammar:
            return await fixGrammar(request.inputText)
        case .summarize:
            return summarize(request.inputText)
        case .complete:
            return complete(request.inputText)
        case .rewrite:
            return rewrite(request.inputText)
        case .translate:
            return "[Local translation not available. Use Cloud AI for translation.]"
        case .expandOutline:
            return expandOutline(request.inputText)
        case .tone:
            return "[Local tone change not available. Use Cloud AI for tone adjustment.]"
        }
    }

    @MainActor
    private func fixGrammar(_ text: String) -> String {
        #if canImport(AppKit)
        // Use NSSpellChecker for basic grammar corrections
        // NSSpellChecker must be used on the main thread
        let checker = NSSpellChecker.shared
        var corrected = text as NSString

        var searchStart = 0
        while searchStart < corrected.length {
            let misspelledRange = checker.checkSpelling(
                of: corrected as String,
                startingAt: searchStart
            )

            if misspelledRange.location == NSNotFound { break }

            if let correction = checker.correction(
                forWordRange: misspelledRange,
                in: corrected as String,
                language: checker.language(),
                inSpellDocumentWithTag: 0
            ) {
                corrected = corrected.replacingCharacters(in: misspelledRange, with: correction) as NSString
                searchStart = misspelledRange.location + (correction as NSString).length
            } else {
                searchStart = NSMaxRange(misspelledRange)
            }
        }

        return corrected as String
        #else
        return text
        #endif
    }

    private func summarize(_ text: String) -> String {
        // Simple extractive summary: take the first sentence of each paragraph
        let paragraphs = text.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let sentences = paragraphs.compactMap { paragraph -> String? in
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            // Get first sentence
            if let range = trimmed.range(of: "[.!?]", options: .regularExpression) {
                return String(trimmed[trimmed.startIndex...range.lowerBound])
            }
            return trimmed.count > 100 ? String(trimmed.prefix(100)) + "..." : trimmed
        }

        return sentences.joined(separator: " ")
    }

    private func complete(_ text: String) -> String {
        // Basic completion: suggest continuation based on context
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasSuffix(":") {
            return "\n\n- "
        }
        if trimmed.hasSuffix("?") {
            return "\n\n[Answer here]"
        }

        return " [Continue writing...]"
    }

    private func rewrite(_ text: String) -> String {
        // Very basic rewrite: just clean up whitespace
        let lines = text.components(separatedBy: "\n")
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        return cleaned
    }

    private func expandOutline(_ text: String) -> String {
        // Take bullet points and expand them into paragraph starters
        let lines = text.components(separatedBy: "\n")
        var expanded: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                expanded.append("\n## \(content)\n\n[Expand on \(content) here...]\n")
            } else if !trimmed.isEmpty {
                expanded.append(line)
            }
        }

        return expanded.joined(separator: "\n")
    }
}
