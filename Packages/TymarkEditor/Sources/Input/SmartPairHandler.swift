import Foundation
import AppKit

// MARK: - Smart Pair Handler

public final class SmartPairHandler {

    // MARK: - Properties

    private let pairs: [Character: Character] = [
        "(": ")",
        "[": "]",
        "{": "}",
        "\"": "\"",
        "'": "'",
        "`": "`",
        "*": "*",
        "_": "_"
    ]

    private let closePairs: Set<Character> = [")", "]", "}", "\"", "'", "`"]

    public var isEnabled: Bool = true

    // MARK: - Public API

    public func handleInsertion(of character: Character, at location: Int, in text: String) -> String? {
        guard isEnabled else { return nil }

        // Check if it's an opening character
        if let closing = pairs[character] {
            // Insert the pair
            return String(character) + String(closing)
        }

        // Check if it's a closing character that should be skipped
        if closePairs.contains(character) {
            let nsText = text as NSString
            let nextLocation = location + 1
            if nextLocation < nsText.length {
                let nextRange = nsText.rangeOfComposedCharacterSequence(at: nextLocation)
                if let swiftRange = Range(nextRange, in: text),
                   text[swiftRange].first == character {
                    return ""
                }
            }
        }

        return nil
    }

    public func handleDeletion(at location: Int, in text: String) -> NSRange? {
        guard isEnabled else { return nil }
        let nsText = text as NSString
        guard location > 0 && location < nsText.length else { return nil }

        // Get chars using UTF-16-safe range conversion
        let prevRange = NSRange(location: location - 1, length: 1)
        let nextRange = NSRange(location: location, length: 1)
        guard let prevSwiftRange = Range(prevRange, in: text),
              let nextSwiftRange = Range(nextRange, in: text) else { return nil }

        let prevChar = text[prevSwiftRange].first
        let nextChar = text[nextSwiftRange].first

        // Check if they form a pair
        if let prev = prevChar, let next = nextChar,
           let closing = pairs[prev], closing == next {
            return NSRange(location: location - 1, length: 2)
        }

        return nil
    }

    public func shouldSkipClosingCharacter(_ character: Character, at location: Int, in text: String) -> Bool {
        guard isEnabled else { return false }
        let nsText = text as NSString
        guard location < nsText.length else { return false }

        let charRange = NSRange(location: location, length: 1)
        guard let swiftRange = Range(charRange, in: text) else { return false }
        let nextChar = text[swiftRange].first

        return nextChar == character && closePairs.contains(character)
    }
}

// MARK: - Smart List Handler

public final class SmartListHandler {

    // MARK: - Properties

    public var isEnabled: Bool = true

    // MARK: - List Types

    private enum ListType {
        case unordered(marker: String)
        case ordered(number: Int)
        case task(checked: Bool)
    }

    // MARK: - Public API

    public func handleNewline(at location: Int, in text: String) -> String? {
        guard isEnabled else { return nil }

        // Find the current line
        let lineStart = findLineStart(before: location, in: text)
        let locationIndex = text.index(text.startIndex, offsetBy: min(location, text.count))
        let line = String(text[lineStart..<locationIndex])

        // Check if this line is a list item
        if let listType = parseListType(from: line) {
            // Continue the list
            let continuation = generateContinuation(for: listType, previousLine: line)
            return continuation
        }

        return nil
    }

    public func handleBackspace(at location: Int, in text: String) -> (insertion: String?, range: NSRange)? {
        guard isEnabled else { return nil }
        guard location > 0 else { return nil }

        // Find the current line
        let lineStart = findLineStart(before: location, in: text)
        let locationIndex = text.index(text.startIndex, offsetBy: min(location, text.count))
        let line = String(text[lineStart..<locationIndex])

        // Check if we're at an empty list item
        if isEmptyListItem(line) {
            // Remove the list marker
            let markerEnd = findMarkerEnd(in: line)
            if markerEnd > 0 {
                return ("", NSRange(location: lineStart.utf16Offset(in: text), length: markerEnd))
            }
        }

        return nil
    }

    public func handleTab(at location: Int, in text: String, isShiftTab: Bool = false) -> String? {
        guard isEnabled else { return nil }

        let lineStart = findLineStart(before: location, in: text)
        let locationIndex = text.index(text.startIndex, offsetBy: min(location, text.count))
        let line = String(text[lineStart..<locationIndex])

        // Check if this is a list item
        if isListItem(line) {
            if isShiftTab {
                // Outdent - remove 2 spaces or a tab before the marker
                if line.hasPrefix("  ") || line.hasPrefix("\t") {
                    return ""
                }
            } else {
                // Indent - add 2 spaces
                return "  "
            }
        }

        return nil
    }

    // MARK: - Private Methods

    private func findLineStart(before location: Int, in text: String) -> String.Index {
        let currentIndex = text.index(text.startIndex, offsetBy: min(location, text.count))

        // Look backwards for newline
        var searchIndex = currentIndex
        while searchIndex > text.startIndex {
            let prevIndex = text.index(before: searchIndex)
            if text[prevIndex] == "\n" {
                return searchIndex
            }
            searchIndex = prevIndex
        }

        return text.startIndex
    }

    private func parseListType(from line: String) -> ListType? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Unordered list
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            let marker = String(trimmed.prefix(2))
            return .unordered(marker: marker)
        }

        // Ordered list
        if let match = trimmed.range(of: "^\\d+\\. ", options: .regularExpression) {
            let numberStr = String(trimmed[match].dropLast(2))
            if let number = Int(numberStr) {
                return .ordered(number: number)
            }
        }

        // Task list
        if trimmed.hasPrefix("- [ ] ") {
            return .task(checked: false)
        }
        if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            return .task(checked: true)
        }

        return nil
    }

    private func generateContinuation(for listType: ListType, previousLine: String) -> String {
        // Preserve indentation
        let indentation = previousLine.prefix { $0 == " " || $0 == "\t" }

        switch listType {
        case .unordered(let marker):
            return String(indentation) + marker

        case .ordered(let number):
            return String(indentation) + "\(number + 1). "

        case .task:
            return String(indentation) + "- [ ] "
        }
    }

    private func isEmptyListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Unordered
        if trimmed == "-" || trimmed == "*" || trimmed == "+" {
            return true
        }
        if trimmed == "- " || trimmed == "* " || trimmed == "+ " {
            return true
        }

        // Ordered
        if trimmed.range(of: "^\\d+\\.$", options: .regularExpression) != nil {
            return true
        }
        if trimmed.range(of: "^\\d+\\. $", options: .regularExpression) != nil {
            return true
        }

        // Task
        if trimmed == "- [ ]" || trimmed == "- [x]" || trimmed == "- [X]" {
            return true
        }
        if trimmed == "- [ ] " || trimmed == "- [x] " || trimmed == "- [X] " {
            return true
        }

        return false
    }

    private func isListItem(_ line: String) -> Bool {
        return parseListType(from: line) != nil
    }

    private func findMarkerEnd(in line: String) -> Int {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return line.range(of: trimmed.prefix(2))?.upperBound.utf16Offset(in: line) ?? 2
        }

        if let match = trimmed.range(of: "^\\d+\\. ", options: .regularExpression) {
            let marker = trimmed[match]
            return line.range(of: marker)?.upperBound.utf16Offset(in: line) ?? marker.count
        }

        if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            return line.range(of: trimmed.prefix(6))?.upperBound.utf16Offset(in: line) ?? 6
        }

        return 0
    }
}

// MARK: - Keybinding Handler

/// Handles keyboard shortcuts by delegating to a CommandRegistry.
/// Integrates JSON-based keybinding configuration with the command system.
public final class KeybindingHandler {

    // MARK: - Properties

    public typealias KeybindingAction = () -> Bool

    private var keybindings: [String: KeybindingAction] = [:]
    private var commandPaletteHandler: (() -> Void)?
    private weak var commandRegistry: CommandRegistry?
    private var configuration: KeybindingConfiguration

    // MARK: - Initialization

    public init(configuration: KeybindingConfiguration = .default) {
        self.configuration = configuration
        setupDefaultKeybindings()
    }

    // MARK: - Public API

    /// Attach a CommandRegistry so keybindings can dispatch through the command system.
    @MainActor
    public func setCommandRegistry(_ registry: CommandRegistry) {
        self.commandRegistry = registry

        // Sync the configuration's bindings into the registry's shortcut overrides
        for entry in configuration.bindings {
            registry.setShortcut(entry.key, for: entry.commandID)
        }
    }

    /// Load a new keybinding configuration (e.g., from JSON).
    @MainActor
    public func loadConfiguration(_ config: KeybindingConfiguration) {
        self.configuration = config

        // Re-sync with registry
        if let registry = commandRegistry {
            registry.resetAllShortcuts()
            for entry in config.bindings {
                registry.setShortcut(entry.key, for: entry.commandID)
            }
        }
    }

    public func registerKeybinding(_ keyCombo: String, action: @escaping KeybindingAction) {
        keybindings[keyCombo.lowercased()] = action
    }

    public func unregisterKeybinding(_ keyCombo: String) {
        keybindings.removeValue(forKey: keyCombo.lowercased())
    }

    @MainActor
    public func handleKeyEvent(_ event: NSEvent) -> Bool {
        // First, try the CommandRegistry
        if let registry = commandRegistry, registry.handleKeyEvent(event) {
            return true
        }

        // Fall back to local keybindings
        let keyCombo = KeyComboParser.keyComboString(from: event)
        if let action = keybindings[keyCombo] {
            return action()
        }

        return false
    }

    public func setCommandPaletteHandler(_ handler: @escaping () -> Void) {
        self.commandPaletteHandler = handler
    }

    public func showCommandPalette() {
        commandPaletteHandler?()
    }

    /// Returns the current keybinding configuration.
    public var currentConfiguration: KeybindingConfiguration {
        return configuration
    }

    // MARK: - Private Methods

    private func setupDefaultKeybindings() {
        // Command Palette fallback (also registered in the CommandRegistry)
        registerKeybinding("cmd+shift+p") { [weak self] in
            self?.showCommandPalette()
            return true
        }
    }
}
