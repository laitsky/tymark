import Cocoa

// MARK: - Find & Replace Engine

@MainActor
public final class FindReplaceEngine: ObservableObject {

    // MARK: - Published State

    @Published public var searchText: String = "" {
        didSet { if searchText != oldValue { invalidateMatches() } }
    }
    @Published public var replaceText: String = ""
    @Published public var isRegexEnabled: Bool = false {
        didSet { if isRegexEnabled != oldValue { invalidateMatches() } }
    }
    @Published public var isCaseSensitive: Bool = false {
        didSet { if isCaseSensitive != oldValue { invalidateMatches() } }
    }
    @Published public var isWholeWord: Bool = false {
        didSet { if isWholeWord != oldValue { invalidateMatches() } }
    }

    @Published public private(set) var matches: [NSRange] = []
    @Published public private(set) var currentMatchIndex: Int = -1
    @Published public private(set) var regexError: String?

    // MARK: - Private

    private weak var textView: NSTextView?

    // MARK: - Initialization

    public init() {}

    // MARK: - Configuration

    public func attach(to textView: NSTextView) {
        self.textView = textView
    }

    // MARK: - Search

    public func search(in text: String, preservePosition: Bool = false) {
        let previousLocation = preservePosition && currentMatchIndex >= 0 && currentMatchIndex < matches.count
            ? matches[currentMatchIndex].location : nil

        matches.removeAll()
        currentMatchIndex = -1
        regexError = nil
        clearHighlights()

        guard !searchText.isEmpty else { return }

        if isRegexEnabled {
            searchWithRegex(in: text)
        } else {
            searchPlainText(in: text)
        }

        highlightMatches()

        if !matches.isEmpty {
            if let prevLoc = previousLocation {
                // Find the nearest match at or after the previous position
                currentMatchIndex = matches.firstIndex(where: { $0.location >= prevLoc }) ?? 0
            } else {
                currentMatchIndex = 0
            }
            scrollToCurrentMatch()
        }
    }

    private func searchPlainText(in text: String) {
        let nsText = text as NSString
        var options: NSString.CompareOptions = []
        if !isCaseSensitive {
            options.insert(.caseInsensitive)
        }

        var searchRange = NSRange(location: 0, length: nsText.length)
        while searchRange.location < nsText.length {
            let foundRange = nsText.range(of: searchText, options: options, range: searchRange)
            guard foundRange.location != NSNotFound else { break }

            if isWholeWord {
                if isWholeWordMatch(foundRange, in: nsText) {
                    matches.append(foundRange)
                }
            } else {
                matches.append(foundRange)
            }

            searchRange.location = NSMaxRange(foundRange)
            searchRange.length = nsText.length - searchRange.location
        }
    }

    private func searchWithRegex(in text: String) {
        var regexOptions: NSRegularExpression.Options = []
        if !isCaseSensitive {
            regexOptions.insert(.caseInsensitive)
        }

        do {
            let regex = try NSRegularExpression(pattern: searchText, options: regexOptions)
            let nsText = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

            for result in results {
                let range = result.range
                if isWholeWord {
                    if isWholeWordMatch(range, in: nsText) {
                        matches.append(range)
                    }
                } else {
                    matches.append(range)
                }
            }
            return
        } catch {
            regexError = error.localizedDescription
            return
        }
    }

    private func isWholeWordMatch(_ range: NSRange, in nsText: NSString) -> Bool {
        let wordChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let text = nsText as String

        // Check character before (using composed character sequence for Unicode safety)
        if range.location > 0 {
            let beforeRange = nsText.rangeOfComposedCharacterSequence(at: range.location - 1)
            if let swiftRange = Range(beforeRange, in: text) {
                let charBefore = text[swiftRange]
                if charBefore.unicodeScalars.allSatisfy({ wordChars.contains($0) }) {
                    return false
                }
            }
        }

        // Check character after
        let afterIndex = NSMaxRange(range)
        if afterIndex < nsText.length {
            let afterRange = nsText.rangeOfComposedCharacterSequence(at: afterIndex)
            if let swiftRange = Range(afterRange, in: text) {
                let charAfter = text[swiftRange]
                if charAfter.unicodeScalars.allSatisfy({ wordChars.contains($0) }) {
                    return false
                }
            }
        }

        return true
    }

    // MARK: - Navigation

    public func findNext() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matches.count
        scrollToCurrentMatch()
        highlightMatches()
    }

    public func findPrevious() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matches.count) % matches.count
        scrollToCurrentMatch()
        highlightMatches()
    }

    // MARK: - Replace

    public func replaceCurrent() {
        guard currentMatchIndex >= 0 && currentMatchIndex < matches.count else { return }
        guard let textView = textView else { return }

        let range = matches[currentMatchIndex]
        guard range.location + range.length <= (textView.string as NSString).length else { return }

        if textView.shouldChangeText(in: range, replacementString: replaceText) {
            textView.textStorage?.replaceCharacters(in: range, with: replaceText)
            textView.didChangeText()
        }

        // Re-search after replacement, preserving position
        search(in: textView.string, preservePosition: true)
    }

    public func replaceAll() {
        guard !matches.isEmpty else { return }
        guard let textView = textView else { return }

        // Replace from end to start to keep ranges valid
        let sortedMatches = matches.sorted { $0.location > $1.location }

        textView.undoManager?.beginUndoGrouping()
        for range in sortedMatches {
            guard range.location + range.length <= (textView.string as NSString).length else { continue }
            if textView.shouldChangeText(in: range, replacementString: replaceText) {
                textView.textStorage?.replaceCharacters(in: range, with: replaceText)
                textView.didChangeText()
            }
        }
        textView.undoManager?.endUndoGrouping()

        // Clear matches after replace all
        matches.removeAll()
        currentMatchIndex = -1
        clearHighlights()
    }

    // MARK: - Highlighting

    private func highlightMatches() {
        guard let textView = textView,
              let layoutManager = textView.layoutManager else { return }

        // Clear previous highlights
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

        // Highlight all matches in a subtle color
        let matchColor = NSColor.systemYellow.withAlphaComponent(0.3)
        for range in matches {
            guard NSMaxRange(range) <= (textView.string as NSString).length else { continue }
            layoutManager.addTemporaryAttribute(.backgroundColor, value: matchColor, forCharacterRange: range)
        }

        // Highlight current match more strongly
        if currentMatchIndex >= 0 && currentMatchIndex < matches.count {
            let currentRange = matches[currentMatchIndex]
            guard NSMaxRange(currentRange) <= (textView.string as NSString).length else { return }
            let currentColor = NSColor.systemOrange.withAlphaComponent(0.5)
            layoutManager.addTemporaryAttribute(.backgroundColor, value: currentColor, forCharacterRange: currentRange)
        }
    }

    private func clearHighlights() {
        guard let textView = textView,
              let layoutManager = textView.layoutManager else { return }

        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
    }

    private func scrollToCurrentMatch() {
        guard currentMatchIndex >= 0 && currentMatchIndex < matches.count else { return }
        let range = matches[currentMatchIndex]
        textView?.scrollRangeToVisible(range)
        textView?.showFindIndicator(for: range)
    }

    private func invalidateMatches() {
        guard let textView = textView else { return }
        search(in: textView.string)
    }

    // MARK: - Status

    public var matchCountDescription: String {
        if let error = regexError {
            return "Invalid regex: \(error)"
        }
        guard !matches.isEmpty else {
            return searchText.isEmpty ? "" : "No results"
        }
        return "\(currentMatchIndex + 1) of \(matches.count)"
    }
}
