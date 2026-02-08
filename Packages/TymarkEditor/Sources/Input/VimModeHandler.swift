import Foundation
import AppKit

// MARK: - Vim Mode

public enum VimMode: String, CaseIterable, Sendable {
    case normal
    case insert
    case visual
    case command
}

// MARK: - Vim Motion

public enum VimMotion: Sendable {
    case left
    case right
    case up
    case down
    case wordForward
    case wordBackward
    case lineStart
    case lineEnd
    case documentStart
    case documentEnd
    case pageUp
    case pageDown
    case findChar(Character)
    case findCharBackward(Character)
}

// MARK: - Vim Action

public enum VimAction: Sendable {
    case move(VimMotion)
    case delete(VimMotion?)
    case change(VimMotion?)
    case yank(VimMotion?)
    case put
    case undo
    case redo
    case insertAtCursor
    case insertAtLineStart
    case appendAfterCursor
    case appendAtLineEnd
    case openLineBelow
    case openLineAbove
    case replaceChar
    case deleteChar
    case joinLines
    case enterVisual
    case enterVisualLine
    case enterCommand
    case exitToNormal
    case repeatLastChange
}

// MARK: - Vim Mode Handler

@MainActor
public final class VimModeHandler: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var mode: VimMode = .normal
    @Published public private(set) var pendingKeys: String = ""
    @Published public private(set) var statusMessage: String = ""
    @Published public var isEnabled: Bool = false

    // MARK: - Properties

    public weak var textView: NSTextView?

    private var repeatCount: Int = 0
    private var pendingOperator: String?
    private var lastChange: (() -> Void)?
    private var yankBuffer: String = ""
    private var commandBuffer: String = ""

    // MARK: - Initialization

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    // MARK: - Public API

    /// Handle a key event when Vim mode is active.
    /// Returns `true` if the event was consumed.
    public func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isEnabled else { return false }
        guard let chars = event.charactersIgnoringModifiers else { return false }

        // In insert mode, only handle Escape to return to normal
        if mode == .insert {
            return handleInsertMode(event, chars: chars)
        }

        // In command mode, handle command line input
        if mode == .command {
            return handleCommandMode(event, chars: chars)
        }

        // In visual mode
        if mode == .visual {
            return handleVisualMode(event, chars: chars)
        }

        // Normal mode
        return handleNormalMode(event, chars: chars)
    }

    /// Transition to a specific mode.
    public func setMode(_ newMode: VimMode) {
        let previousMode = mode
        mode = newMode

        switch newMode {
        case .normal:
            pendingKeys = ""
            pendingOperator = nil
            repeatCount = 0
            statusMessage = "-- NORMAL --"

            // Move cursor back one position when leaving insert mode
            if previousMode == .insert, let tv = textView {
                let loc = tv.selectedRange().location
                if loc > 0 {
                    tv.setSelectedRange(NSRange(location: loc - 1, length: 0))
                }
            }

        case .insert:
            statusMessage = "-- INSERT --"

        case .visual:
            statusMessage = "-- VISUAL --"

        case .command:
            commandBuffer = ":"
            statusMessage = ":"
        }
    }

    // MARK: - Normal Mode

    private func handleNormalMode(_ event: NSEvent, chars: String) -> Bool {
        // Handle escape
        if event.keyCode == 53 {
            setMode(.normal)
            return true
        }

        // Build up repeat count
        if let digit = chars.first, digit.isNumber && digit != "0" && pendingOperator == nil && repeatCount > 0 || (digit.isNumber && digit != "0" && pendingKeys.isEmpty) {
            if let d = Int(String(digit)) {
                repeatCount = repeatCount * 10 + d
                pendingKeys += String(digit)
                return true
            }
        }

        let count = max(1, repeatCount)

        // Check for pending operator
        if let op = pendingOperator {
            let consumed = handleOperatorPending(op, chars: chars, count: count)
            pendingOperator = nil
            pendingKeys = ""
            repeatCount = 0
            return consumed
        }

        // Handle single key commands
        let handled = executeSingleKey(chars, event: event, count: count)

        if handled {
            pendingKeys = ""
            repeatCount = 0
        }

        return handled
    }

    private func executeSingleKey(_ chars: String, event: NSEvent, count: Int) -> Bool {
        guard let tv = textView else { return false }

        switch chars {
        // Movement
        case "h":
            executeAction(.move(.left), count: count)
            return true
        case "j":
            executeAction(.move(.down), count: count)
            return true
        case "k":
            executeAction(.move(.up), count: count)
            return true
        case "l":
            executeAction(.move(.right), count: count)
            return true
        case "w":
            executeAction(.move(.wordForward), count: count)
            return true
        case "b":
            executeAction(.move(.wordBackward), count: count)
            return true
        case "0":
            if repeatCount == 0 {
                executeAction(.move(.lineStart), count: 1)
                return true
            }
            return false
        case "$":
            executeAction(.move(.lineEnd), count: 1)
            return true

        // Insertion
        case "i":
            setMode(.insert)
            return true
        case "I":
            executeAction(.move(.lineStart), count: 1)
            setMode(.insert)
            return true
        case "a":
            let loc = tv.selectedRange().location
            let len = (tv.string as NSString).length
            if loc < len {
                tv.setSelectedRange(NSRange(location: loc + 1, length: 0))
            }
            setMode(.insert)
            return true
        case "A":
            executeAction(.move(.lineEnd), count: 1)
            let loc = tv.selectedRange().location
            let len = (tv.string as NSString).length
            if loc < len {
                tv.setSelectedRange(NSRange(location: loc + 1, length: 0))
            }
            setMode(.insert)
            return true
        case "o":
            executeAction(.move(.lineEnd), count: 1)
            tv.insertText("\n", replacementRange: tv.selectedRange())
            setMode(.insert)
            return true
        case "O":
            executeAction(.move(.lineStart), count: 1)
            let loc = tv.selectedRange().location
            tv.insertText("\n", replacementRange: NSRange(location: loc, length: 0))
            tv.setSelectedRange(NSRange(location: loc, length: 0))
            setMode(.insert)
            return true

        // Operators (wait for motion)
        case "d":
            pendingOperator = "d"
            pendingKeys = "d"
            return true
        case "c":
            pendingOperator = "c"
            pendingKeys = "c"
            return true
        case "y":
            pendingOperator = "y"
            pendingKeys = "y"
            return true

        // Single char operations
        case "x":
            deleteCharAtCursor(count: count)
            return true
        case "p":
            pasteAfterCursor()
            return true
        case "P":
            pasteBeforeCursor()
            return true
        case "u":
            for _ in 0..<count { tv.undoManager?.undo() }
            return true
        case "r":
            if event.modifierFlags.contains(.control) {
                for _ in 0..<count { tv.undoManager?.redo() }
                return true
            }
            return false
        case "J":
            joinLines()
            return true

        // Visual mode
        case "v":
            setMode(.visual)
            return true

        // Command mode
        case ":":
            setMode(.command)
            return true

        // Document movement
        case "G":
            if repeatCount > 0 {
                goToLine(repeatCount)
            } else {
                executeAction(.move(.documentEnd), count: 1)
            }
            return true

        // Scroll
        case "f" where event.modifierFlags.contains(.control):
            executeAction(.move(.pageDown), count: count)
            return true
        case "b" where event.modifierFlags.contains(.control):
            executeAction(.move(.pageUp), count: count)
            return true

        default:
            return false
        }
    }

    // MARK: - Operator Pending

    private func handleOperatorPending(_ op: String, chars: String, count: Int) -> Bool {
        guard let tv = textView else { return false }

        // Double operator (e.g., dd, cc, yy) operates on current line
        if chars == op {
            let range = currentLineRange(in: tv)
            switch op {
            case "d":
                yankBuffer = (tv.string as NSString).substring(with: range)
                tv.replaceCharacters(in: range, with: "")
            case "c":
                yankBuffer = (tv.string as NSString).substring(with: range)
                tv.replaceCharacters(in: range, with: "")
                setMode(.insert)
            case "y":
                yankBuffer = (tv.string as NSString).substring(with: range)
            default:
                break
            }
            return true
        }

        // Operator + motion
        let startLoc = tv.selectedRange().location
        var handled = false

        switch chars {
        case "w":
            for _ in 0..<count { moveWordForward(in: tv) }
            handled = true
        case "b":
            for _ in 0..<count { moveWordBackward(in: tv) }
            handled = true
        case "0":
            moveToLineStart(in: tv)
            handled = true
        case "$":
            moveToLineEnd(in: tv)
            handled = true
        case "G":
            moveToDocumentEnd(in: tv)
            handled = true
        default:
            break
        }

        if handled {
            let endLoc = tv.selectedRange().location
            let opRange: NSRange
            if endLoc >= startLoc {
                opRange = NSRange(location: startLoc, length: endLoc - startLoc)
            } else {
                opRange = NSRange(location: endLoc, length: startLoc - endLoc)
            }

            if opRange.length > 0 {
                yankBuffer = (tv.string as NSString).substring(with: opRange)
            }

            switch op {
            case "d":
                if opRange.length > 0 {
                    tv.replaceCharacters(in: opRange, with: "")
                    tv.setSelectedRange(NSRange(location: opRange.location, length: 0))
                }
            case "c":
                if opRange.length > 0 {
                    tv.replaceCharacters(in: opRange, with: "")
                    tv.setSelectedRange(NSRange(location: opRange.location, length: 0))
                }
                setMode(.insert)
            case "y":
                tv.setSelectedRange(NSRange(location: startLoc, length: 0))
            default:
                break
            }
        }

        return handled
    }

    // MARK: - Insert Mode

    private func handleInsertMode(_ event: NSEvent, chars: String) -> Bool {
        // Escape to return to normal mode
        if event.keyCode == 53 {
            setMode(.normal)
            return true
        }
        // Let the text view handle everything else
        return false
    }

    // MARK: - Visual Mode

    private func handleVisualMode(_ event: NSEvent, chars: String) -> Bool {
        // Escape to return to normal
        if event.keyCode == 53 {
            setMode(.normal)
            return true
        }

        guard let tv = textView else { return false }
        let currentRange = tv.selectedRange()

        switch chars {
        case "h":
            if currentRange.length > 0 {
                tv.setSelectedRange(NSRange(location: currentRange.location, length: currentRange.length - 1))
            }
            return true
        case "l":
            tv.setSelectedRange(NSRange(location: currentRange.location, length: currentRange.length + 1))
            return true
        case "j":
            extendSelectionDown(in: tv)
            return true
        case "k":
            extendSelectionUp(in: tv)
            return true
        case "d", "x":
            if currentRange.length > 0 {
                yankBuffer = (tv.string as NSString).substring(with: currentRange)
                tv.replaceCharacters(in: currentRange, with: "")
            }
            setMode(.normal)
            return true
        case "y":
            if currentRange.length > 0 {
                yankBuffer = (tv.string as NSString).substring(with: currentRange)
            }
            setMode(.normal)
            return true
        case "c":
            if currentRange.length > 0 {
                yankBuffer = (tv.string as NSString).substring(with: currentRange)
                tv.replaceCharacters(in: currentRange, with: "")
            }
            setMode(.insert)
            return true
        default:
            return false
        }
    }

    // MARK: - Command Mode

    private func handleCommandMode(_ event: NSEvent, chars: String) -> Bool {
        // Escape exits command mode
        if event.keyCode == 53 {
            setMode(.normal)
            return true
        }

        // Enter executes the command
        if event.keyCode == 36 {
            executeCommandLineCommand(commandBuffer)
            setMode(.normal)
            return true
        }

        // Backspace
        if event.keyCode == 51 {
            if commandBuffer.count > 1 {
                commandBuffer.removeLast()
                statusMessage = commandBuffer
            } else {
                setMode(.normal)
            }
            return true
        }

        // Append character
        commandBuffer += chars
        statusMessage = commandBuffer
        return true
    }

    private func executeCommandLineCommand(_ command: String) {
        let cmd = String(command.dropFirst()) // Remove the ":"

        switch cmd.trimmingCharacters(in: .whitespaces) {
        case "w":
            statusMessage = "File saved"
        case "q":
            statusMessage = "Use :q! to force quit"
        case "q!":
            NSApplication.shared.terminate(nil)
        case "wq":
            statusMessage = "Saved and quitting"
        case let lineStr where Int(lineStr) != nil:
            if let line = Int(lineStr) {
                goToLine(line)
            }
        default:
            statusMessage = "Unknown command: \(cmd)"
        }
    }

    // MARK: - Action Execution

    private func executeAction(_ action: VimAction, count: Int) {
        guard let tv = textView else { return }

        switch action {
        case .move(let motion):
            for _ in 0..<count {
                executeMotion(motion, in: tv)
            }
        default:
            break
        }
    }

    private func executeMotion(_ motion: VimMotion, in tv: NSTextView) {
        switch motion {
        case .left:
            let loc = tv.selectedRange().location
            if loc > 0 {
                tv.setSelectedRange(NSRange(location: loc - 1, length: 0))
            }
        case .right:
            let loc = tv.selectedRange().location
            let len = (tv.string as NSString).length
            if loc < len - 1 {
                tv.setSelectedRange(NSRange(location: loc + 1, length: 0))
            }
        case .up:
            tv.moveUp(nil)
        case .down:
            tv.moveDown(nil)
        case .wordForward:
            moveWordForward(in: tv)
        case .wordBackward:
            moveWordBackward(in: tv)
        case .lineStart:
            moveToLineStart(in: tv)
        case .lineEnd:
            moveToLineEnd(in: tv)
        case .documentStart:
            tv.setSelectedRange(NSRange(location: 0, length: 0))
        case .documentEnd:
            moveToDocumentEnd(in: tv)
        case .pageUp:
            tv.pageUp(nil)
        case .pageDown:
            tv.pageDown(nil)
        default:
            break
        }
    }

    // MARK: - Movement Helpers

    private func moveWordForward(in tv: NSTextView) {
        let nsString = tv.string as NSString
        let loc = tv.selectedRange().location
        let length = nsString.length
        guard loc < length else { return }

        var pos = loc
        // Skip current word characters
        while pos < length && !isWordBoundary(nsString.character(at: pos)) {
            pos += 1
        }
        // Skip whitespace
        while pos < length && isWordBoundary(nsString.character(at: pos)) {
            pos += 1
        }
        tv.setSelectedRange(NSRange(location: pos, length: 0))
    }

    private func moveWordBackward(in tv: NSTextView) {
        let nsString = tv.string as NSString
        var pos = tv.selectedRange().location
        guard pos > 0 else { return }

        pos -= 1
        // Skip whitespace
        while pos > 0 && isWordBoundary(nsString.character(at: pos)) {
            pos -= 1
        }
        // Skip word characters
        while pos > 0 && !isWordBoundary(nsString.character(at: pos - 1)) {
            pos -= 1
        }
        tv.setSelectedRange(NSRange(location: pos, length: 0))
    }

    private func moveToLineStart(in tv: NSTextView) {
        let nsString = tv.string as NSString
        let loc = tv.selectedRange().location
        let lineRange = nsString.lineRange(for: NSRange(location: loc, length: 0))
        tv.setSelectedRange(NSRange(location: lineRange.location, length: 0))
    }

    private func moveToLineEnd(in tv: NSTextView) {
        let nsString = tv.string as NSString
        let loc = tv.selectedRange().location
        let lineRange = nsString.lineRange(for: NSRange(location: loc, length: 0))
        let end = NSMaxRange(lineRange)
        // Position before the newline
        let finalPos = end > lineRange.location && end <= nsString.length && nsString.character(at: end - 1) == 0x0A ? end - 1 : end
        tv.setSelectedRange(NSRange(location: max(lineRange.location, finalPos - 1), length: 0))
    }

    private func moveToDocumentEnd(in tv: NSTextView) {
        let length = (tv.string as NSString).length
        tv.setSelectedRange(NSRange(location: max(0, length - 1), length: 0))
    }

    private func isWordBoundary(_ char: unichar) -> Bool {
        let c = Character(UnicodeScalar(char)!)
        return c.isWhitespace || c.isNewline || c.isPunctuation
    }

    // MARK: - Edit Helpers

    private func deleteCharAtCursor(count: Int) {
        guard let tv = textView else { return }
        let loc = tv.selectedRange().location
        let nsString = tv.string as NSString
        let deleteCount = min(count, nsString.length - loc)
        guard deleteCount > 0 else { return }

        let range = NSRange(location: loc, length: deleteCount)
        yankBuffer = nsString.substring(with: range)
        tv.replaceCharacters(in: range, with: "")
    }

    private func pasteAfterCursor() {
        guard let tv = textView, !yankBuffer.isEmpty else { return }
        let loc = min(tv.selectedRange().location + 1, (tv.string as NSString).length)
        tv.insertText(yankBuffer, replacementRange: NSRange(location: loc, length: 0))
    }

    private func pasteBeforeCursor() {
        guard let tv = textView, !yankBuffer.isEmpty else { return }
        let loc = tv.selectedRange().location
        tv.insertText(yankBuffer, replacementRange: NSRange(location: loc, length: 0))
    }

    private func joinLines() {
        guard let tv = textView else { return }
        let nsString = tv.string as NSString
        let loc = tv.selectedRange().location
        let lineRange = nsString.lineRange(for: NSRange(location: loc, length: 0))
        let lineEnd = NSMaxRange(lineRange)
        guard lineEnd < nsString.length else { return }

        // Find next line's first non-whitespace
        let nextLineRange = nsString.lineRange(for: NSRange(location: lineEnd, length: 0))
        let nextLineStr = nsString.substring(with: nextLineRange)
        let trimmed = nextLineStr.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove newline + leading whitespace of next line, replace with space
        let removeRange = NSRange(location: lineEnd - 1, length: nextLineRange.length - trimmed.count + 1)
        tv.replaceCharacters(in: removeRange, with: " ")
    }

    private func currentLineRange(in tv: NSTextView) -> NSRange {
        let nsString = tv.string as NSString
        let loc = tv.selectedRange().location
        return nsString.lineRange(for: NSRange(location: loc, length: 0))
    }

    private func goToLine(_ line: Int) {
        guard let tv = textView else { return }
        let lines = tv.string.components(separatedBy: "\n")
        let targetLine = min(max(1, line), lines.count) - 1

        var offset = 0
        for i in 0..<targetLine {
            offset += (lines[i] as NSString).length + 1
        }
        tv.setSelectedRange(NSRange(location: min(offset, (tv.string as NSString).length), length: 0))
    }

    private func extendSelectionDown(in tv: NSTextView) {
        let range = tv.selectedRange()
        let nsString = tv.string as NSString
        let end = NSMaxRange(range)
        if end < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: end, length: 0))
            tv.setSelectedRange(NSRange(location: range.location, length: NSMaxRange(lineRange) - range.location))
        }
    }

    private func extendSelectionUp(in tv: NSTextView) {
        let range = tv.selectedRange()
        if range.location > 0 {
            let nsString = tv.string as NSString
            let prevLine = nsString.lineRange(for: NSRange(location: range.location - 1, length: 0))
            tv.setSelectedRange(NSRange(location: prevLine.location, length: NSMaxRange(range) - prevLine.location))
        }
    }
}
