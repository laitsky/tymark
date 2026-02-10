import Foundation

public enum ThemeManagerError: LocalizedError {
    case failedToLoadThemesDirectory(URL, Error)
    case failedToLoadThemeFile(URL, Error)
    case failedToSaveTheme(String, Error)
    case failedToDeleteTheme(String, Error)
    case failedToExportTheme(URL, Error)
    case failedToImportTheme(URL, Error)

    public var errorDescription: String? {
        switch self {
        case let .failedToLoadThemesDirectory(url, underlying):
            return "Failed to load themes directory at \(url.path): \(underlying.localizedDescription)"
        case let .failedToLoadThemeFile(url, underlying):
            return "Failed to load theme file \(url.lastPathComponent): \(underlying.localizedDescription)"
        case let .failedToSaveTheme(identifier, underlying):
            return "Failed to save theme '\(identifier)': \(underlying.localizedDescription)"
        case let .failedToDeleteTheme(identifier, underlying):
            return "Failed to delete theme '\(identifier)': \(underlying.localizedDescription)"
        case let .failedToExportTheme(url, underlying):
            return "Failed to export theme to \(url.path): \(underlying.localizedDescription)"
        case let .failedToImportTheme(url, underlying):
            return "Failed to import theme from \(url.path): \(underlying.localizedDescription)"
        }
    }
}

actor ThemeFileSystemActor {
    private let fileManager = FileManager.default

    func ensureDirectoryExists(at directory: URL) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func listThemeFiles(in directory: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    func readData(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func writeData(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    func removeItemIfExists(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }
}
