import Foundation
import AppKit
import Combine

// MARK: - Theme Manager

@MainActor
public final class ThemeManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var currentTheme: Theme
    @Published public var availableThemes: [Theme] = []
    @Published public var customThemes: [Theme] = []
    @Published public private(set) var lastError: ThemeManagerError?

    // MARK: - Singleton

    public static let shared = ThemeManager()

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let customThemesDirectory: URL
    private let builtInThemes: [Theme]
    private let fileSystem = ThemeFileSystemActor()

    public var onError: ((ThemeManagerError) -> Void)?

    // MARK: - Initialization

    private init() {
        // Set up custom themes directory
        self.customThemesDirectory = Self.tymarkApplicationSupportDirectory(appending: "Themes")

        // Load built-in themes first
        self.builtInThemes = BuiltInThemes.allThemes
        self.currentTheme = BuiltInThemes.light

        // Update available themes
        updateAvailableThemes()
        restorePersistedThemeSelection()

        Task { [weak self] in
            await self?.loadCustomThemes()
        }

        // Set up system appearance listener
        setupSystemAppearanceListener()
    }

    // MARK: - Public API

    public func setTheme(_ theme: Theme) {
        currentTheme = theme

        // Save preference
        UserDefaults.standard.set(theme.identifier, forKey: "selectedThemeIdentifier")

        // Notify observers
        NotificationCenter.default.post(name: .themeChanged, object: theme)
    }

    public func setTheme(identifier: String) {
        if let theme = availableThemes.first(where: { $0.identifier == identifier }) {
            setTheme(theme)
        }
    }

    public func theme(identifier: String) -> Theme? {
        return availableThemes.first(where: { $0.identifier == identifier })
    }

    public func createCustomTheme(
        name: String,
        basedOn baseTheme: Theme? = nil,
        colorOverrides: [String: CodableColor] = [:]
    ) -> Theme {
        let base = baseTheme ?? currentTheme

        // Apply color overrides
        var colors = base.colors
        for (key, color) in colorOverrides {
            switch key {
            case "background": colors.background = color
            case "text": colors.text = color
            case "secondaryText": colors.secondaryText = color
            case "accent": colors.accent = color
            case "link": colors.link = color
            case "codeBackground": colors.codeBackground = color
            case "codeText": colors.codeText = color
            case "heading": colors.heading = color
            case "selection": colors.selection = color
            case "cursor": colors.cursor = color
            default: break
            }
        }

        let newTheme = Theme(
            name: name,
            identifier: "custom.\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            isBuiltIn: false,
            colors: colors,
            fonts: base.fonts,
            spacing: base.spacing,
            editor: base.editor
        )

        persistCustomTheme(newTheme)

        // Add to list
        customThemes.append(newTheme)
        updateAvailableThemes()

        return newTheme
    }

    public func deleteCustomTheme(_ theme: Theme) {
        guard !theme.isBuiltIn else { return }

        deletePersistedTheme(theme)

        // Remove from list
        customThemes.removeAll { $0.id == theme.id }
        updateAvailableThemes()

        // If this was the current theme, switch to default
        if currentTheme.id == theme.id {
            setTheme(BuiltInThemes.light)
        }
    }

    public func duplicateTheme(_ theme: Theme, withName name: String) -> Theme {
        let duplicated = Theme(
            name: name,
            identifier: "custom.\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            isBuiltIn: false,
            colors: theme.colors,
            fonts: theme.fonts,
            spacing: theme.spacing,
            editor: theme.editor
        )

        persistCustomTheme(duplicated)
        customThemes.append(duplicated)
        updateAvailableThemes()

        return duplicated
    }

    public func exportTheme(_ theme: Theme, to url: URL) async throws {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(theme)
            try await fileSystem.writeData(data, to: url)
        } catch {
            let wrapped = ThemeManagerError.failedToExportTheme(url, error)
            reportError(wrapped)
            throw wrapped
        }
    }

    public func importTheme(from url: URL) async throws -> Theme {
        do {
            let data = try await fileSystem.readData(at: url)
            let decoded = try JSONDecoder().decode(Theme.self, from: data)

            let importedTheme = Theme(
                id: UUID(),
                name: decoded.name,
                identifier: "imported.\(decoded.identifier)",
                isBuiltIn: false,
                colors: decoded.colors,
                fonts: decoded.fonts,
                spacing: decoded.spacing,
                editor: decoded.editor
            )

            try await saveCustomTheme(importedTheme)
            customThemes.append(importedTheme)
            updateAvailableThemes()
            return importedTheme
        } catch {
            let wrapped = ThemeManagerError.failedToImportTheme(url, error)
            reportError(wrapped)
            throw wrapped
        }
    }

    public func matchesSystemAppearance(_ theme: Theme) -> Bool {
        let effectiveAppearance = NSApp.effectiveAppearance
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        switch theme.identifier {
        case "light", "sepia", "solarized-light":
            return !isDark
        case "dark", "nord", "solarized-dark":
            return isDark
        default:
            return false
        }
    }

    // MARK: - Private Methods

    private static func tymarkApplicationSupportDirectory(appending component: String) -> URL {
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport.appendingPathComponent("Tymark/\(component)", isDirectory: true)
        }
        let fallbackBase = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return fallbackBase.appendingPathComponent("Tymark/\(component)", isDirectory: true)
    }

    private func updateAvailableThemes() {
        availableThemes = builtInThemes + customThemes
    }

    private func reportError(_ error: ThemeManagerError) {
        lastError = error
        onError?(error)
    }

    private func restorePersistedThemeSelection() {
        guard let identifier = UserDefaults.standard.string(forKey: "selectedThemeIdentifier"),
              let selected = availableThemes.first(where: { $0.identifier == identifier }) else {
            return
        }
        currentTheme = selected
    }

    private func setupSystemAppearanceListener() {
        // Listen for system appearance changes
        DistributedNotificationCenter.default
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .sink { [weak self] _ in
                self?.handleSystemAppearanceChange()
            }
            .store(in: &cancellables)
    }

    private func handleSystemAppearanceChange() {
        // Check if user wants to follow system appearance
        let followSystem = UserDefaults.standard.bool(forKey: "followSystemAppearance")
        guard followSystem else { return }

        let effectiveAppearance = NSApp.effectiveAppearance
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        if isDark {
            setTheme(BuiltInThemes.dark)
        } else {
            setTheme(BuiltInThemes.light)
        }
    }

    private func loadCustomThemes() async {
        do {
            try await fileSystem.ensureDirectoryExists(at: customThemesDirectory)
            let themeFiles = try await fileSystem.listThemeFiles(in: customThemesDirectory)

            var loadedThemes: [Theme] = []
            loadedThemes.reserveCapacity(themeFiles.count)

            for fileURL in themeFiles {
                do {
                    let data = try await fileSystem.readData(at: fileURL)
                    let theme = try JSONDecoder().decode(Theme.self, from: data)
                    loadedThemes.append(theme)
                } catch {
                    reportError(.failedToLoadThemeFile(fileURL, error))
                }
            }

            customThemes = loadedThemes
            updateAvailableThemes()
            restorePersistedThemeSelection()
        } catch {
            reportError(.failedToLoadThemesDirectory(customThemesDirectory, error))
        }
    }

    private func persistCustomTheme(_ theme: Theme) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await saveCustomTheme(theme)
            } catch {
                reportError(.failedToSaveTheme(theme.identifier, error))
            }
        }
    }

    private func saveCustomTheme(_ theme: Theme) async throws {
        try await fileSystem.ensureDirectoryExists(at: customThemesDirectory)
        let themeURL = customThemesDirectory.appendingPathComponent("\(theme.identifier).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(theme)
        try await fileSystem.writeData(data, to: themeURL)
    }

    private func deletePersistedTheme(_ theme: Theme) {
        Task { [weak self] in
            guard let self else { return }
            let themeURL = customThemesDirectory.appendingPathComponent("\(theme.identifier).json")
            do {
                try await fileSystem.removeItemIfExists(at: themeURL)
            } catch {
                reportError(.failedToDeleteTheme(theme.identifier, error))
            }
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let themeChanged = Notification.Name("TymarkThemeChanged")
}

// MARK: - Built-in Themes

public struct BuiltInThemes {

    // MARK: - Light Theme

    public static let light = Theme(
        name: "Light",
        identifier: "light",
        isBuiltIn: true,
        colors: ThemeColors(
            background: CodableColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            text: CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            secondaryText: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0),
            accent: CodableColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
            link: CodableColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
            codeBackground: CodableColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0),
            codeText: CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            heading: CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            quoteBorder: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0),
            quoteText: CodableColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0),
            listMarker: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0),
            syntaxHidden: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.3),
            selection: CodableColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.3),
            cursor: CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            sidebarBackground: CodableColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0),
            sidebarText: CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        ),
        fonts: ThemeFonts(
            body: CodableFont(family: "SF Pro", size: 14),
            code: CodableFont(family: "SF Mono", size: 13)
        )
    )

    // MARK: - Dark Theme

    public static let dark = Theme(
        name: "Dark",
        identifier: "dark",
        isBuiltIn: true,
        colors: ThemeColors(
            background: CodableColor(color: NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)),
            text: CodableColor(color: NSColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)),
            secondaryText: CodableColor(color: NSColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0)),
            accent: CodableColor(color: NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)),
            link: CodableColor(color: NSColor(red: 0.25, green: 0.65, blue: 1.0, alpha: 1.0)),
            codeBackground: CodableColor(color: NSColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0)),
            codeText: CodableColor(color: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)),
            heading: CodableColor(color: NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)),
            quoteBorder: CodableColor(color: NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)),
            quoteText: CodableColor(color: NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)),
            listMarker: CodableColor(color: NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)),
            syntaxHidden: CodableColor(color: NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.3)),
            selection: CodableColor(color: NSColor(red: 0.18, green: 0.45, blue: 0.9, alpha: 0.5)),
            cursor: CodableColor(color: NSColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)),
            sidebarBackground: CodableColor(color: NSColor(red: 0.09, green: 0.09, blue: 0.1, alpha: 1.0)),
            sidebarText: CodableColor(color: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0))
        ),
        fonts: ThemeFonts(
            body: CodableFont(family: "SF Pro", size: 14),
            code: CodableFont(family: "SF Mono", size: 13)
        )
    )

    // MARK: - Sepia Theme

    public static let sepia = Theme(
        name: "Sepia",
        identifier: "sepia",
        isBuiltIn: true,
        colors: ThemeColors(
            background: CodableColor(color: NSColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1.0)),
            text: CodableColor(color: NSColor(red: 0.25, green: 0.2, blue: 0.15, alpha: 1.0)),
            secondaryText: CodableColor(color: NSColor(red: 0.5, green: 0.42, blue: 0.35, alpha: 1.0)),
            accent: CodableColor(color: NSColor(red: 0.65, green: 0.35, blue: 0.15, alpha: 1.0)),
            link: CodableColor(color: NSColor(red: 0.5, green: 0.25, blue: 0.1, alpha: 1.0)),
            codeBackground: CodableColor(color: NSColor(red: 0.92, green: 0.88, blue: 0.82, alpha: 1.0)),
            codeText: CodableColor(color: NSColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)),
            heading: CodableColor(color: NSColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)),
            quoteBorder: CodableColor(color: NSColor(red: 0.75, green: 0.65, blue: 0.55, alpha: 1.0)),
            quoteText: CodableColor(color: NSColor(red: 0.5, green: 0.42, blue: 0.35, alpha: 1.0)),
            listMarker: CodableColor(color: NSColor(red: 0.6, green: 0.5, blue: 0.4, alpha: 1.0)),
            syntaxHidden: CodableColor(color: NSColor(red: 0.7, green: 0.6, blue: 0.5, alpha: 0.3)),
            selection: CodableColor(color: NSColor(red: 0.85, green: 0.75, blue: 0.6, alpha: 0.5)),
            cursor: CodableColor(color: NSColor(red: 0.25, green: 0.2, blue: 0.15, alpha: 1.0)),
            sidebarBackground: CodableColor(color: NSColor(red: 0.95, green: 0.92, blue: 0.86, alpha: 1.0)),
            sidebarText: CodableColor(color: NSColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0))
        ),
        fonts: ThemeFonts(
            body: CodableFont(family: "New York", size: 15),
            code: CodableFont(family: "SF Mono", size: 13)
        )
    )

    // MARK: - Nord Theme

    public static let nord = Theme(
        name: "Nord",
        identifier: "nord",
        isBuiltIn: true,
        colors: ThemeColors(
            background: CodableColor(color: NSColor(red: 0.18, green: 0.20, blue: 0.25, alpha: 1.0)),
            text: CodableColor(color: NSColor(red: 0.87, green: 0.89, blue: 0.93, alpha: 1.0)),
            secondaryText: CodableColor(color: NSColor(red: 0.60, green: 0.65, blue: 0.72, alpha: 1.0)),
            accent: CodableColor(color: NSColor(red: 0.53, green: 0.75, blue: 0.81, alpha: 1.0)),
            link: CodableColor(color: NSColor(red: 0.53, green: 0.75, blue: 0.81, alpha: 1.0)),
            codeBackground: CodableColor(color: NSColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1.0)),
            codeText: CodableColor(color: NSColor(red: 0.80, green: 0.82, blue: 0.85, alpha: 1.0)),
            heading: CodableColor(color: NSColor(red: 0.92, green: 0.93, blue: 0.95, alpha: 1.0)),
            quoteBorder: CodableColor(color: NSColor(red: 0.40, green: 0.45, blue: 0.52, alpha: 1.0)),
            quoteText: CodableColor(color: NSColor(red: 0.65, green: 0.70, blue: 0.78, alpha: 1.0)),
            listMarker: CodableColor(color: NSColor(red: 0.55, green: 0.60, blue: 0.68, alpha: 1.0)),
            syntaxHidden: CodableColor(color: NSColor(red: 0.45, green: 0.50, blue: 0.58, alpha: 0.3)),
            selection: CodableColor(color: NSColor(red: 0.25, green: 0.35, blue: 0.48, alpha: 0.6)),
            cursor: CodableColor(color: NSColor(red: 0.87, green: 0.89, blue: 0.93, alpha: 1.0)),
            sidebarBackground: CodableColor(color: NSColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1.0)),
            sidebarText: CodableColor(color: NSColor(red: 0.80, green: 0.82, blue: 0.85, alpha: 1.0))
        ),
        fonts: ThemeFonts(
            body: CodableFont(family: "SF Pro", size: 14),
            code: CodableFont(family: "SF Mono", size: 13)
        )
    )

    // MARK: - Solarized Light

    public static let solarizedLight = Theme(
        name: "Solarized Light",
        identifier: "solarized-light",
        isBuiltIn: true,
        colors: ThemeColors(
            background: CodableColor(color: NSColor(red: 0.99, green: 0.96, blue: 0.89, alpha: 1.0)),
            text: CodableColor(color: NSColor(red: 0.20, green: 0.20, blue: 0.16, alpha: 1.0)),
            secondaryText: CodableColor(color: NSColor(red: 0.50, green: 0.48, blue: 0.42, alpha: 1.0)),
            accent: CodableColor(color: NSColor(red: 0.15, green: 0.45, blue: 0.60, alpha: 1.0)),
            link: CodableColor(color: NSColor(red: 0.15, green: 0.35, blue: 0.55, alpha: 1.0)),
            codeBackground: CodableColor(color: NSColor(red: 0.94, green: 0.91, blue: 0.84, alpha: 1.0)),
            codeText: CodableColor(color: NSColor(red: 0.25, green: 0.25, blue: 0.20, alpha: 1.0)),
            heading: CodableColor(color: NSColor(red: 0.15, green: 0.15, blue: 0.12, alpha: 1.0)),
            quoteBorder: CodableColor(color: NSColor(red: 0.70, green: 0.68, blue: 0.62, alpha: 1.0)),
            quoteText: CodableColor(color: NSColor(red: 0.45, green: 0.43, blue: 0.37, alpha: 1.0)),
            listMarker: CodableColor(color: NSColor(red: 0.55, green: 0.53, blue: 0.47, alpha: 1.0)),
            syntaxHidden: CodableColor(color: NSColor(red: 0.65, green: 0.63, blue: 0.57, alpha: 0.3)),
            selection: CodableColor(color: NSColor(red: 0.80, green: 0.77, blue: 0.70, alpha: 0.6)),
            cursor: CodableColor(color: NSColor(red: 0.20, green: 0.20, blue: 0.16, alpha: 1.0)),
            sidebarBackground: CodableColor(color: NSColor(red: 0.97, green: 0.94, blue: 0.87, alpha: 1.0)),
            sidebarText: CodableColor(color: NSColor(red: 0.30, green: 0.28, blue: 0.24, alpha: 1.0))
        ),
        fonts: ThemeFonts(
            body: CodableFont(family: "SF Pro", size: 14),
            code: CodableFont(family: "SF Mono", size: 13)
        )
    )

    // MARK: - Solarized Dark

    public static let solarizedDark = Theme(
        name: "Solarized Dark",
        identifier: "solarized-dark",
        isBuiltIn: true,
        colors: ThemeColors(
            background: CodableColor(color: NSColor(red: 0.00, green: 0.17, blue: 0.21, alpha: 1.0)),
            text: CodableColor(color: NSColor(red: 0.71, green: 0.73, blue: 0.68, alpha: 1.0)),
            secondaryText: CodableColor(color: NSColor(red: 0.52, green: 0.54, blue: 0.50, alpha: 1.0)),
            accent: CodableColor(color: NSColor(red: 0.15, green: 0.55, blue: 0.65, alpha: 1.0)),
            link: CodableColor(color: NSColor(red: 0.15, green: 0.45, blue: 0.60, alpha: 1.0)),
            codeBackground: CodableColor(color: NSColor(red: 0.03, green: 0.13, blue: 0.17, alpha: 1.0)),
            codeText: CodableColor(color: NSColor(red: 0.80, green: 0.82, blue: 0.76, alpha: 1.0)),
            heading: CodableColor(color: NSColor(red: 0.80, green: 0.82, blue: 0.77, alpha: 1.0)),
            quoteBorder: CodableColor(color: NSColor(red: 0.35, green: 0.37, blue: 0.33, alpha: 1.0)),
            quoteText: CodableColor(color: NSColor(red: 0.60, green: 0.62, blue: 0.57, alpha: 1.0)),
            listMarker: CodableColor(color: NSColor(red: 0.50, green: 0.52, blue: 0.47, alpha: 1.0)),
            syntaxHidden: CodableColor(color: NSColor(red: 0.40, green: 0.42, blue: 0.38, alpha: 0.3)),
            selection: CodableColor(color: NSColor(red: 0.15, green: 0.30, blue: 0.35, alpha: 0.6)),
            cursor: CodableColor(color: NSColor(red: 0.71, green: 0.73, blue: 0.68, alpha: 1.0)),
            sidebarBackground: CodableColor(color: NSColor(red: 0.00, green: 0.14, blue: 0.18, alpha: 1.0)),
            sidebarText: CodableColor(color: NSColor(red: 0.68, green: 0.70, blue: 0.65, alpha: 1.0))
        ),
        fonts: ThemeFonts(
            body: CodableFont(family: "SF Pro", size: 14),
            code: CodableFont(family: "SF Mono", size: 13)
        )
    )

    // MARK: - All Themes

    public static let allThemes: [Theme] = [
        light,
        dark,
        sepia,
        nord,
        solarizedLight,
        solarizedDark
    ]
}
