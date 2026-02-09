import Foundation
import AppKit

// MARK: - Command Category

public enum CommandCategory: String, CaseIterable, Codable, Sendable {
    case file = "File"
    case edit = "Edit"
    case view = "View"
    case format = "Format"
    case navigate = "Navigate"
    case export = "Export"
    case tools = "Tools"
}

// MARK: - Command Definition

public struct CommandDefinition: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: CommandCategory
    public let defaultShortcut: String?
    public let isEnabled: @Sendable () -> Bool
    public let execute: @Sendable @MainActor () -> Void

    public init(
        id: String,
        name: String,
        category: CommandCategory,
        defaultShortcut: String? = nil,
        isEnabled: @escaping @Sendable () -> Bool = { true },
        execute: @escaping @Sendable @MainActor () -> Void
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.defaultShortcut = defaultShortcut
        self.isEnabled = isEnabled
        self.execute = execute
    }
}

// MARK: - Command Registry

@MainActor
public final class CommandRegistry: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var commands: [String: CommandDefinition] = [:]
    @Published public private(set) var shortcutOverrides: [String: String] = [:]

    // MARK: - Private Properties

    private var sortedCommandsCache: [CommandDefinition]?

    // MARK: - Initialization

    public init() {}

    // MARK: - Registration

    public func register(_ command: CommandDefinition) {
        commands[command.id] = command
        sortedCommandsCache = nil
    }

    public func register(_ commands: [CommandDefinition]) {
        for command in commands {
            self.commands[command.id] = command
        }
        sortedCommandsCache = nil
    }

    public func unregister(_ commandID: String) {
        commands.removeValue(forKey: commandID)
        sortedCommandsCache = nil
    }

    // MARK: - Execution

    public func execute(_ commandID: String) -> Bool {
        guard let command = commands[commandID], command.isEnabled() else {
            return false
        }
        command.execute()
        return true
    }

    // MARK: - Lookup

    public func command(for id: String) -> CommandDefinition? {
        return commands[id]
    }

    public func shortcut(for commandID: String) -> String? {
        return shortcutOverrides[commandID] ?? commands[commandID]?.defaultShortcut
    }

    public func commandID(for shortcut: String) -> String? {
        // Check overrides first
        if let id = shortcutOverrides.first(where: { $0.value == shortcut.lowercased() })?.key {
            return id
        }

        // Check defaults
        return commands.values.first(where: {
            $0.defaultShortcut?.lowercased() == shortcut.lowercased()
        })?.id
    }

    // MARK: - Shortcut Customization

    public func setShortcut(_ shortcut: String?, for commandID: String) {
        if let shortcut = shortcut {
            shortcutOverrides[commandID] = shortcut.lowercased()
        } else {
            shortcutOverrides.removeValue(forKey: commandID)
        }
        saveShortcutOverrides()
    }

    public func resetShortcut(for commandID: String) {
        shortcutOverrides.removeValue(forKey: commandID)
        saveShortcutOverrides()
    }

    public func resetAllShortcuts() {
        shortcutOverrides.removeAll()
        saveShortcutOverrides()
    }

    // MARK: - Sorting & Filtering

    public var sortedCommands: [CommandDefinition] {
        if let cached = sortedCommandsCache {
            return cached
        }
        let sorted = commands.values.sorted { $0.name < $1.name }
        sortedCommandsCache = sorted
        return sorted
    }

    public func commands(in category: CommandCategory) -> [CommandDefinition] {
        return sortedCommands.filter { $0.category == category }
    }

    public func search(query: String) -> [CommandDefinition] {
        guard !query.isEmpty else { return sortedCommands }

        let normalizedQuery = query.lowercased()
        return sortedCommands.filter { command in
            command.name.lowercased().contains(normalizedQuery) ||
            command.id.lowercased().contains(normalizedQuery) ||
            command.category.rawValue.lowercased().contains(normalizedQuery)
        }
    }

    // MARK: - Persistence

    public func loadShortcutOverrides() {
        guard let data = UserDefaults.standard.data(forKey: "TymarkKeybindingOverrides"),
              let overrides = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        shortcutOverrides = overrides
    }

    private func saveShortcutOverrides() {
        guard let data = try? JSONEncoder().encode(shortcutOverrides) else { return }
        UserDefaults.standard.set(data, forKey: "TymarkKeybindingOverrides")
    }

    // MARK: - Handle Key Event

    /// Attempts to handle a key event by looking up the matching command.
    /// Returns `true` if a command was found and executed.
    public func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCombo = KeyComboParser.keyComboString(from: event)
        guard let commandID = commandID(for: keyCombo) else { return false }
        return execute(commandID)
    }
}

// MARK: - Key Combo Parser

public enum KeyComboParser {

    /// Converts an NSEvent into a normalized key combo string like "cmd+shift+p".
    public static func keyComboString(from event: NSEvent) -> String {
        var parts: [String] = []

        if event.modifierFlags.contains(.command) {
            parts.append("cmd")
        }
        if event.modifierFlags.contains(.control) {
            parts.append("ctrl")
        }
        if event.modifierFlags.contains(.option) {
            parts.append("alt")
        }
        if event.modifierFlags.contains(.shift) {
            parts.append("shift")
        }

        if let chars = event.charactersIgnoringModifiers?.lowercased() {
            // Map special keys
            let mapped = mapSpecialKey(chars, keyCode: event.keyCode)
            parts.append(mapped)
        }

        return parts.joined(separator: "+")
    }

    /// Converts a human-readable shortcut string like "Cmd+Shift+P" to a normalized key combo.
    public static func normalize(_ shortcut: String) -> String {
        let parts = shortcut.lowercased()
            .replacingOccurrences(of: "⌘", with: "cmd")
            .replacingOccurrences(of: "⇧", with: "shift")
            .replacingOccurrences(of: "⌥", with: "alt")
            .replacingOccurrences(of: "⌃", with: "ctrl")
            .components(separatedBy: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return parts.joined(separator: "+")
    }

    /// Converts a normalized key combo to a human-readable display string.
    public static func displayString(for keyCombo: String) -> String {
        let parts = keyCombo.components(separatedBy: "+")
        var display: [String] = []

        for part in parts {
            switch part.lowercased() {
            case "cmd": display.append("⌘")
            case "ctrl": display.append("⌃")
            case "alt": display.append("⌥")
            case "shift": display.append("⇧")
            case "enter", "return": display.append("↩")
            case "tab": display.append("⇥")
            case "escape", "esc": display.append("⎋")
            case "delete", "backspace": display.append("⌫")
            case "up": display.append("↑")
            case "down": display.append("↓")
            case "left": display.append("←")
            case "right": display.append("→")
            case "space": display.append("Space")
            default: display.append(part.uppercased())
            }
        }

        return display.joined()
    }

    private static func mapSpecialKey(_ chars: String, keyCode: UInt16) -> String {
        switch keyCode {
        case 36: return "return"
        case 48: return "tab"
        case 53: return "escape"
        case 51: return "delete"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        case 49: return "space"
        default: return chars
        }
    }
}
