import Cocoa

// MARK: - Text Manipulating Protocol

@MainActor
public protocol TextManipulating: AnyObject {
    /// Wraps the current selection with prefix and suffix. If already wrapped, toggles off.
    /// If no selection, inserts markers and places cursor between.
    func wrapSelection(prefix: String, suffix: String)

    /// Toggles a line prefix (e.g. "# ", "- ", "1. ") on the current line(s).
    /// For headings, replaces existing prefix. For lists, toggles on/off.
    func toggleLinePrefix(_ prefix: String)

    /// Inserts text at the current cursor position.
    func insertAtCursor(_ text: String)

    /// Inserts a markdown link, wrapping selected text as the title.
    func insertLink(url: String)

    /// Moves the current line up by one.
    func moveLineUp()

    /// Moves the current line down by one.
    func moveLineDown()

    /// Duplicates the current line.
    func duplicateLine()

    /// Increases the editor zoom level.
    func zoomIn()

    /// Decreases the editor zoom level.
    func zoomOut()

    /// Resets zoom to default (1.0).
    func resetZoom()

    /// The currently selected text.
    var selectedText: String { get }

    /// The current selection range.
    var currentSelectedRange: NSRange { get }

    /// The full text content.
    var fullText: String { get }
}

// MARK: - TymarkTextView + TextManipulating

extension TymarkTextView: TextManipulating {

    public var selectedText: String {
        let range = selectedRange()
        guard range.length > 0 else { return "" }
        return (string as NSString).substring(with: range)
    }

    public var currentSelectedRange: NSRange {
        return selectedRange()
    }

    public var fullText: String {
        return string
    }

    public func wrapSelection(prefix: String, suffix: String) {
        let range = selectedRange()
        guard let textStorage = self.textStorage else { return }
        let nsString = string as NSString

        if range.length > 0 {
            // Text is selected - check if already wrapped (toggle off)
            let selectedStr = nsString.substring(with: range)

            if selectedStr.hasPrefix(prefix) && selectedStr.hasSuffix(suffix) && selectedStr.count > prefix.count + suffix.count {
                // Already wrapped - remove the wrapping
                let inner = String(selectedStr.dropFirst(prefix.count).dropLast(suffix.count))
                if shouldChangeText(in: range, replacementString: inner) {
                    textStorage.replaceCharacters(in: range, with: inner)
                    didChangeText()
                    setSelectedRange(NSRange(location: range.location, length: inner.count))
                }
                return
            }

            // Check if surrounding text wraps the selection
            let beforeStart = range.location - prefix.count
            let afterEnd = NSMaxRange(range)
            if beforeStart >= 0 && afterEnd + suffix.count <= nsString.length {
                let before = nsString.substring(with: NSRange(location: beforeStart, length: prefix.count))
                let after = nsString.substring(with: NSRange(location: afterEnd, length: suffix.count))
                if before == prefix && after == suffix {
                    // Remove surrounding markers
                    let fullRange = NSRange(location: beforeStart, length: prefix.count + range.length + suffix.count)
                    let inner = nsString.substring(with: range)
                    if shouldChangeText(in: fullRange, replacementString: inner) {
                        textStorage.replaceCharacters(in: fullRange, with: inner)
                        didChangeText()
                        setSelectedRange(NSRange(location: beforeStart, length: inner.count))
                    }
                    return
                }
            }

            // Wrap the selection
            let wrapped = prefix + selectedStr + suffix
            if shouldChangeText(in: range, replacementString: wrapped) {
                textStorage.replaceCharacters(in: range, with: wrapped)
                didChangeText()
                setSelectedRange(NSRange(location: range.location + prefix.count, length: selectedStr.count))
            }
        } else {
            // No selection - insert markers and place cursor between
            let insertion = prefix + suffix
            if shouldChangeText(in: range, replacementString: insertion) {
                textStorage.replaceCharacters(in: range, with: insertion)
                didChangeText()
                setSelectedRange(NSRange(location: range.location + prefix.count, length: 0))
            }
        }
    }

    public func toggleLinePrefix(_ prefix: String) {
        let range = selectedRange()
        let nsString = string as NSString

        // Get the full range of affected lines
        let lineRange = nsString.lineRange(for: range)
        let linesText = nsString.substring(with: lineRange)
        var lines = linesText.components(separatedBy: "\n")

        // Remove trailing empty element from lineRange including trailing newline
        let hasTrailingNewline = lines.last?.isEmpty == true && lines.count > 1
        if hasTrailingNewline {
            lines.removeLast()
        }

        // Check if this is a heading prefix
        let isHeadingPrefix = prefix.trimmingCharacters(in: .whitespaces).allSatisfy({ $0 == "#" })

        var newLines: [String] = []
        for line in lines {
            if isHeadingPrefix {
                // For headings: remove any existing heading prefix, then apply new one (or toggle off)
                let existingLevel = line.prefix(while: { $0 == "#" }).count
                if existingLevel > 0 {
                    // Remove existing heading prefix
                    var stripped = String(line.dropFirst(existingLevel))
                    if stripped.hasPrefix(" ") { stripped = String(stripped.dropFirst()) }

                    let newLevel = prefix.trimmingCharacters(in: .whitespaces).count
                    if existingLevel == newLevel {
                        // Same level - toggle off
                        newLines.append(stripped)
                    } else {
                        // Different level - apply new
                        newLines.append(prefix + stripped)
                    }
                } else {
                    // No heading - add prefix
                    newLines.append(prefix + line)
                }
            } else {
                // For lists, blockquotes: toggle on/off
                if line.hasPrefix(prefix) {
                    // Remove prefix
                    newLines.append(String(line.dropFirst(prefix.count)))
                } else {
                    // Add prefix
                    newLines.append(prefix + line)
                }
            }
        }

        // Restore trailing newline if it was present
        if hasTrailingNewline {
            newLines.append("")
        }
        let newText = newLines.joined(separator: "\n")
        guard let textStorage = self.textStorage else { return }

        if shouldChangeText(in: lineRange, replacementString: newText) {
            textStorage.replaceCharacters(in: lineRange, with: newText)
            didChangeText()
            // Place cursor at end of modified text
            let newLength = (newText as NSString).length
            setSelectedRange(NSRange(location: lineRange.location + newLength, length: 0))
        }
    }

    public func insertAtCursor(_ text: String) {
        let range = selectedRange()
        guard let textStorage = self.textStorage else { return }

        if shouldChangeText(in: range, replacementString: text) {
            textStorage.replaceCharacters(in: range, with: text)
            didChangeText()
            setSelectedRange(NSRange(location: range.location + (text as NSString).length, length: 0))
        }
    }

    public func insertLink(url: String) {
        let range = selectedRange()
        let selected = selectedText

        let linkText: String
        if selected.isEmpty {
            linkText = "[link](\(url))"
        } else {
            linkText = "[\(selected)](\(url))"
        }

        guard let textStorage = self.textStorage else { return }
        if shouldChangeText(in: range, replacementString: linkText) {
            textStorage.replaceCharacters(in: range, with: linkText)
            didChangeText()

            if selected.isEmpty {
                // Select "link" text so user can type title
                setSelectedRange(NSRange(location: range.location + 1, length: 4))
            } else {
                // Place cursor at end of URL
                let endPos = range.location + (linkText as NSString).length
                setSelectedRange(NSRange(location: endPos, length: 0))
            }
        }
    }

    public func moveLineUp() {
        let nsString = string as NSString
        let range = selectedRange()
        let lineRange = nsString.lineRange(for: range)

        // Can't move first line up
        guard lineRange.location > 0 else { return }

        // Get previous line range
        let prevLineEnd = lineRange.location - 1
        let prevLineRange = nsString.lineRange(for: NSRange(location: prevLineEnd, length: 0))

        let currentLine = nsString.substring(with: lineRange)
        let prevLine = nsString.substring(with: prevLineRange)

        guard let textStorage = self.textStorage else { return }

        // Swap lines
        let combinedRange = NSRange(location: prevLineRange.location, length: prevLineRange.length + lineRange.length)
        let swapped = currentLine + prevLine

        undoManager?.beginUndoGrouping()
        if shouldChangeText(in: combinedRange, replacementString: swapped) {
            textStorage.replaceCharacters(in: combinedRange, with: swapped)
            didChangeText()
            // Move cursor up with the line
            let newLocation = prevLineRange.location + (range.location - lineRange.location)
            setSelectedRange(NSRange(location: newLocation, length: range.length))
        }
        undoManager?.endUndoGrouping()
    }

    public func moveLineDown() {
        let nsString = string as NSString
        let range = selectedRange()
        let lineRange = nsString.lineRange(for: range)

        // Can't move last line down
        let lineEnd = NSMaxRange(lineRange)
        guard lineEnd < nsString.length else { return }

        // Get next line range
        let nextLineRange = nsString.lineRange(for: NSRange(location: lineEnd, length: 0))

        let currentLine = nsString.substring(with: lineRange)
        let nextLine = nsString.substring(with: nextLineRange)

        guard let textStorage = self.textStorage else { return }

        // Swap lines
        let combinedRange = NSRange(location: lineRange.location, length: lineRange.length + nextLineRange.length)
        let swapped = nextLine + currentLine

        undoManager?.beginUndoGrouping()
        if shouldChangeText(in: combinedRange, replacementString: swapped) {
            textStorage.replaceCharacters(in: combinedRange, with: swapped)
            didChangeText()
            // Move cursor down with the line
            let newLocation = lineRange.location + nextLineRange.length + (range.location - lineRange.location)
            setSelectedRange(NSRange(location: newLocation, length: range.length))
        }
        undoManager?.endUndoGrouping()
    }

    public func duplicateLine() {
        let nsString = string as NSString
        let range = selectedRange()
        let lineRange = nsString.lineRange(for: range)
        let lineText = nsString.substring(with: lineRange)

        guard let textStorage = self.textStorage else { return }

        // Insert a copy of the line after the current line
        let insertionPoint = NSMaxRange(lineRange)
        let duplicate: String
        if lineText.hasSuffix("\n") {
            duplicate = lineText
        } else {
            duplicate = "\n" + lineText
        }

        if shouldChangeText(in: NSRange(location: insertionPoint, length: 0), replacementString: duplicate) {
            textStorage.replaceCharacters(in: NSRange(location: insertionPoint, length: 0), with: duplicate)
            didChangeText()
            // Move cursor to duplicated line
            let newLocation = insertionPoint + (range.location - lineRange.location)
            if lineText.hasSuffix("\n") {
                setSelectedRange(NSRange(location: newLocation, length: range.length))
            } else {
                setSelectedRange(NSRange(location: newLocation + 1, length: range.length))
            }
        }
    }

    public func zoomIn() {
        zoomMultiplier = min(zoomMultiplier + 0.1, 3.0)
        applyZoom()
    }

    public func zoomOut() {
        zoomMultiplier = max(zoomMultiplier - 0.1, 0.5)
        applyZoom()
    }

    public func resetZoom() {
        zoomMultiplier = 1.0
        applyZoom()
    }
}
