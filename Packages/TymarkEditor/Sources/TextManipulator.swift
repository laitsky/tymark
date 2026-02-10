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

    /// Adds another selection for the next occurrence of the current selection.
    func addNextSelectionOccurrence()

    /// Selects all occurrences of the current selection.
    func selectAllSelectionOccurrences()

    /// Adds a markdown table row below the current row.
    func addTableRowBelow()

    /// Adds a markdown table column after the current column.
    func addTableColumnAfter()

    /// Cycles markdown table alignment for the current column.
    func cycleTableColumnAlignment()

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

    public func addNextSelectionOccurrence() {
        let selected = selectedText
        guard !selected.isEmpty else { return }

        let nsSource = string as NSString
        let selectedRanges = self.selectedRanges
            .map(\.rangeValue)
            .sorted { $0.location < $1.location }

        guard let lastRange = selectedRanges.last else { return }
        let start = NSMaxRange(lastRange)
        guard start < nsSource.length else { return }

        let searchRange = NSRange(location: start, length: nsSource.length - start)
        let next = nsSource.range(of: selected, options: [], range: searchRange)
        guard next.location != NSNotFound else { return }

        if selectedRanges.contains(where: { NSEqualRanges($0, next) }) {
            return
        }

        var newRanges = selectedRanges
        newRanges.append(next)
        let values = newRanges.map { NSValue(range: $0) }
        setSelectedRanges(values, affinity: .downstream, stillSelecting: false)
        scrollRangeToVisible(next)
    }

    public func selectAllSelectionOccurrences() {
        let selected = selectedText
        guard !selected.isEmpty else { return }

        let nsSource = string as NSString
        var foundRanges: [NSRange] = []
        var searchLocation = 0

        while searchLocation < nsSource.length {
            let searchRange = NSRange(location: searchLocation, length: nsSource.length - searchLocation)
            let match = nsSource.range(of: selected, options: [], range: searchRange)
            if match.location == NSNotFound || match.length == 0 {
                break
            }
            foundRanges.append(match)
            searchLocation = NSMaxRange(match)
        }

        guard !foundRanges.isEmpty else { return }
        let values = foundRanges.map { NSValue(range: $0) }
        setSelectedRanges(values, affinity: .downstream, stillSelecting: false)
        if let first = foundRanges.first {
            scrollRangeToVisible(first)
        }
    }

    public func addTableRowBelow() {
        guard let edit = makeTableEditContext() else { return }
        let insertAt = max(2, edit.selectedRowIndex + 1)
        let emptyRow = Array(repeating: "", count: edit.columnCount)
        var lines = edit.lines
        lines.insert(Self.renderTableRow(emptyRow), at: min(insertAt, lines.count))
        replaceTable(in: edit.tableRange, with: lines)
    }

    public func addTableColumnAfter() {
        guard let edit = makeTableEditContext() else { return }
        let insertionIndex = min(edit.columnCount, max(0, edit.selectedColumnIndex + 1))
        var lines = edit.lines

        for index in lines.indices {
            var cells = Self.parseTableRow(lines[index])
            let newCell: String
            if index == 1 {
                newCell = "---"
            } else {
                newCell = ""
            }
            cells.insert(newCell, at: min(insertionIndex, cells.count))
            lines[index] = Self.renderTableRow(cells)
        }

        replaceTable(in: edit.tableRange, with: lines)
    }

    public func cycleTableColumnAlignment() {
        guard let edit = makeTableEditContext(), edit.lines.count > 1 else { return }
        var lines = edit.lines
        var separatorCells = Self.parseTableRow(lines[1])
        let index = min(max(0, edit.selectedColumnIndex), max(0, separatorCells.count - 1))
        guard index < separatorCells.count else { return }

        let current = separatorCells[index].replacingOccurrences(of: " ", with: "")
        let next: String
        switch current {
        case ":---":
            next = ":---:"
        case ":---:":
            next = "---:"
        case "---:":
            next = "---"
        default:
            next = ":---"
        }

        separatorCells[index] = next
        lines[1] = Self.renderTableRow(separatorCells)
        replaceTable(in: edit.tableRange, with: lines)
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

// MARK: - Markdown Table Editing

private extension TymarkTextView {
    struct TableEditContext {
        let tableRange: NSRange
        let lines: [String]
        let selectedRowIndex: Int
        let selectedColumnIndex: Int
        let columnCount: Int
    }

    func makeTableEditContext() -> TableEditContext? {
        let nsSource = string as NSString
        guard nsSource.length > 0 else { return nil }

        let caret = selectedRange().location
        let currentLineRange = nsSource.lineRange(for: NSRange(location: min(caret, nsSource.length), length: 0))
        let currentLine = nsSource.substring(with: currentLineRange)
        guard Self.looksLikeTableLine(currentLine) else { return nil }

        var start = currentLineRange.location
        var end = NSMaxRange(currentLineRange)

        while start > 0 {
            let previousProbe = max(0, start - 1)
            let previousLineRange = nsSource.lineRange(for: NSRange(location: previousProbe, length: 0))
            let previousLine = nsSource.substring(with: previousLineRange)
            if Self.looksLikeTableLine(previousLine) {
                start = previousLineRange.location
            } else {
                break
            }
        }

        while end < nsSource.length {
            let nextLineRange = nsSource.lineRange(for: NSRange(location: end, length: 0))
            let nextLine = nsSource.substring(with: nextLineRange)
            if Self.looksLikeTableLine(nextLine) {
                end = NSMaxRange(nextLineRange)
            } else {
                break
            }
        }

        let tableRange = NSRange(location: start, length: max(0, end - start))
        guard tableRange.length > 0 else { return nil }
        var lines = nsSource.substring(with: tableRange).components(separatedBy: "\n")
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }

        guard lines.count >= 2, Self.isSeparatorRow(lines[1]) else { return nil }

        let lineStartOffsets = Self.computeLineOffsets(for: lines)
        let localLocation = max(0, caret - tableRange.location)
        let selectedRow = Self.rowIndex(for: localLocation, lineOffsets: lineStartOffsets)
        let selectedColumn = Self.columnIndex(
            in: lines[min(max(0, selectedRow), lines.count - 1)],
            localLocation: localLocation - lineStartOffsets[min(max(0, selectedRow), lineStartOffsets.count - 1)]
        )
        let headerColumns = max(1, Self.parseTableRow(lines[0]).count)

        return TableEditContext(
            tableRange: tableRange,
            lines: lines,
            selectedRowIndex: selectedRow,
            selectedColumnIndex: min(max(0, selectedColumn), headerColumns - 1),
            columnCount: headerColumns
        )
    }

    func replaceTable(in range: NSRange, with lines: [String]) {
        guard let textStorage = self.textStorage else { return }
        let rebuilt = lines.joined(separator: "\n") + "\n"

        if shouldChangeText(in: range, replacementString: rebuilt) {
            textStorage.replaceCharacters(in: range, with: rebuilt)
            didChangeText()
            let caret = range.location + rebuilt.utf16.count
            setSelectedRange(NSRange(location: caret, length: 0))
        }
    }

    static func looksLikeTableLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.contains("|")
    }

    static func isSeparatorRow(_ line: String) -> Bool {
        let cells = parseTableRow(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let stripped = cell.replacingOccurrences(of: " ", with: "")
            let withoutColons = stripped.replacingOccurrences(of: ":", with: "")
            return withoutColons.count >= 3 && withoutColons.allSatisfy { $0 == "-" }
        }
    }

    static func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let core = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        guard !core.isEmpty else { return [""] }
        return core.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func renderTableRow(_ cells: [String]) -> String {
        "| " + cells.joined(separator: " | ") + " |"
    }

    static func computeLineOffsets(for lines: [String]) -> [Int] {
        var offsets: [Int] = []
        offsets.reserveCapacity(lines.count)
        var location = 0
        for line in lines {
            offsets.append(location)
            location += (line as NSString).length + 1
        }
        return offsets
    }

    static func rowIndex(for localLocation: Int, lineOffsets: [Int]) -> Int {
        guard !lineOffsets.isEmpty else { return 0 }
        var best = 0
        for index in lineOffsets.indices where lineOffsets[index] <= localLocation {
            best = index
        }
        return best
    }

    static func columnIndex(in line: String, localLocation: Int) -> Int {
        let nsLine = line as NSString
        let safeLocation = max(0, min(localLocation, nsLine.length))
        let prefix = nsLine.substring(to: safeLocation)
        let pipeCount = prefix.filter { $0 == "|" }.count
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let leadingPipeAdjustment = trimmed.hasPrefix("|") ? 1 : 0
        return max(0, pipeCount - leadingPipeAdjustment)
    }
}
