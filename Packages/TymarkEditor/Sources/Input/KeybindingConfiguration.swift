import Foundation

// MARK: - Keybinding Entry

public struct KeybindingEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { commandID }
    public let commandID: String
    public let key: String
    public let when: String?

    public init(commandID: String, key: String, when: String? = nil) {
        self.commandID = commandID
        self.key = key
        self.when = when
    }

    enum CodingKeys: String, CodingKey {
        case commandID = "command"
        case key
        case when
    }
}

// MARK: - Keybinding Configuration

public struct KeybindingConfiguration: Codable, Equatable, Sendable {
    public var version: Int
    public var bindings: [KeybindingEntry]

    public init(version: Int = 1, bindings: [KeybindingEntry] = []) {
        self.version = version
        self.bindings = bindings
    }

    /// The default keybinding configuration shipped with Tymark.
    public static let `default` = KeybindingConfiguration(
        version: 1,
        bindings: [
            // File operations
            KeybindingEntry(commandID: "file.new", key: "cmd+n"),
            KeybindingEntry(commandID: "file.open", key: "cmd+o"),
            KeybindingEntry(commandID: "file.save", key: "cmd+s"),
            KeybindingEntry(commandID: "file.saveAs", key: "cmd+shift+s"),
            KeybindingEntry(commandID: "file.close", key: "cmd+w"),

            // Edit operations
            KeybindingEntry(commandID: "edit.undo", key: "cmd+z"),
            KeybindingEntry(commandID: "edit.redo", key: "cmd+shift+z"),
            KeybindingEntry(commandID: "edit.cut", key: "cmd+x"),
            KeybindingEntry(commandID: "edit.copy", key: "cmd+c"),
            KeybindingEntry(commandID: "edit.paste", key: "cmd+v"),
            KeybindingEntry(commandID: "edit.selectAll", key: "cmd+a"),

            // View operations
            KeybindingEntry(commandID: "view.commandPalette", key: "cmd+shift+p"),
            KeybindingEntry(commandID: "view.quickOpen", key: "cmd+p"),
            KeybindingEntry(commandID: "view.toggleSidebar", key: "cmd+shift+b"),
            KeybindingEntry(commandID: "view.toggleFocusMode", key: "cmd+shift+f"),
            KeybindingEntry(commandID: "view.toggleSourceMode", key: "cmd+/"),
            KeybindingEntry(commandID: "view.zoomIn", key: "cmd+="),
            KeybindingEntry(commandID: "view.zoomOut", key: "cmd+-"),
            KeybindingEntry(commandID: "view.resetZoom", key: "cmd+0"),

            // Format operations
            KeybindingEntry(commandID: "format.bold", key: "cmd+b"),
            KeybindingEntry(commandID: "format.italic", key: "cmd+i"),
            KeybindingEntry(commandID: "format.strikethrough", key: "cmd+shift+x"),
            KeybindingEntry(commandID: "format.inlineCode", key: "cmd+e"),
            KeybindingEntry(commandID: "format.link", key: "cmd+k"),
            KeybindingEntry(commandID: "format.heading1", key: "cmd+1"),
            KeybindingEntry(commandID: "format.heading2", key: "cmd+2"),
            KeybindingEntry(commandID: "format.heading3", key: "cmd+3"),
            KeybindingEntry(commandID: "format.heading4", key: "cmd+4"),
            KeybindingEntry(commandID: "format.heading5", key: "cmd+5"),
            KeybindingEntry(commandID: "format.heading6", key: "cmd+6"),
            KeybindingEntry(commandID: "format.orderedList", key: "cmd+shift+7"),
            KeybindingEntry(commandID: "format.unorderedList", key: "cmd+shift+8"),
            KeybindingEntry(commandID: "format.taskList", key: "cmd+shift+9"),
            KeybindingEntry(commandID: "format.blockquote", key: "cmd+shift+."),
            KeybindingEntry(commandID: "format.codeBlock", key: "cmd+shift+c"),
            KeybindingEntry(commandID: "format.horizontalRule", key: "cmd+shift+-"),

            // Navigate operations
            KeybindingEntry(commandID: "navigate.moveLineUp", key: "alt+up"),
            KeybindingEntry(commandID: "navigate.moveLineDown", key: "alt+down"),
            KeybindingEntry(commandID: "navigate.duplicateLine", key: "cmd+shift+d"),

            // Export operations
            KeybindingEntry(commandID: "export.html", key: "cmd+shift+e"),
            KeybindingEntry(commandID: "export.pdf", key: "cmd+alt+p"),
        ]
    )
}

// MARK: - Keybinding Loader

public final class KeybindingLoader {

    // MARK: - Properties

    private let userConfigURL: URL?

    // MARK: - Initialization

    public init() {
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            self.userConfigURL = appSupport
                .appendingPathComponent("Tymark", isDirectory: true)
                .appendingPathComponent("keybindings.json")
        } else {
            self.userConfigURL = nil
        }
    }

    // MARK: - Loading

    /// Load keybinding configuration, merging user overrides with defaults.
    public func load() -> KeybindingConfiguration {
        // Start with defaults
        var config = KeybindingConfiguration.default

        // Try to load user overrides
        if let userConfig = loadUserConfiguration() {
            config = merge(base: config, overrides: userConfig)
        }

        return config
    }

    /// Load keybinding configuration from a JSON file URL.
    public func load(from url: URL) throws -> KeybindingConfiguration {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(KeybindingConfiguration.self, from: data)
    }

    /// Load configuration from a JSON string.
    public func load(from jsonString: String) throws -> KeybindingConfiguration {
        guard let data = jsonString.data(using: .utf8) else {
            throw KeybindingError.invalidJSON
        }
        return try JSONDecoder().decode(KeybindingConfiguration.self, from: data)
    }

    // MARK: - Saving

    /// Save a keybinding configuration to the user's config directory.
    public func save(_ config: KeybindingConfiguration) throws {
        guard let url = userConfigURL else {
            throw KeybindingError.noConfigDirectory
        }

        // Ensure directory exists
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url)
    }

    /// Save configuration to a specific URL.
    public func save(_ config: KeybindingConfiguration, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url)
    }

    // MARK: - Private

    private func loadUserConfiguration() -> KeybindingConfiguration? {
        guard let url = userConfigURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? load(from: url)
    }

    private func merge(base: KeybindingConfiguration, overrides: KeybindingConfiguration) -> KeybindingConfiguration {
        // Build a map from commandID to override binding
        var overrideMap: [String: KeybindingEntry] = [:]
        for entry in overrides.bindings {
            overrideMap[entry.commandID] = entry
        }

        // Merge: use override if present, otherwise keep base
        var merged: [KeybindingEntry] = []
        var processedIDs: Set<String> = []

        for entry in base.bindings {
            if let override = overrideMap[entry.commandID] {
                merged.append(override)
            } else {
                merged.append(entry)
            }
            processedIDs.insert(entry.commandID)
        }

        // Add any new bindings from overrides that aren't in base
        for entry in overrides.bindings where !processedIDs.contains(entry.commandID) {
            merged.append(entry)
        }

        return KeybindingConfiguration(
            version: max(base.version, overrides.version),
            bindings: merged
        )
    }
}

// MARK: - Keybinding Errors

public enum KeybindingError: Error, LocalizedError {
    case invalidJSON
    case noConfigDirectory
    case invalidKeyCombo(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON keybinding configuration"
        case .noConfigDirectory:
            return "Unable to locate configuration directory"
        case .invalidKeyCombo(let combo):
            return "Invalid key combination: \(combo)"
        }
    }
}
