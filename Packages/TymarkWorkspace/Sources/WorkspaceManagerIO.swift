import Foundation

public enum WorkspaceManagerError: LocalizedError {
    case failedToLoadWorkspaces(URL, Error)
    case failedToSaveWorkspaces(URL, Error)
    case failedToEnumerateDirectory(URL, Error)
    case failedToCreateFile(URL, Error)
    case failedToCreateDirectory(URL, Error)
    case failedToDeleteFile(URL, Error)
    case failedToRenameFile(URL, Error)
    case failedToDuplicateFile(URL, Error)

    public var errorDescription: String? {
        switch self {
        case let .failedToLoadWorkspaces(url, underlying):
            return "Failed to load workspace metadata from \(url.path): \(underlying.localizedDescription)"
        case let .failedToSaveWorkspaces(url, underlying):
            return "Failed to save workspace metadata to \(url.path): \(underlying.localizedDescription)"
        case let .failedToEnumerateDirectory(url, underlying):
            return "Failed to read directory \(url.path): \(underlying.localizedDescription)"
        case let .failedToCreateFile(url, underlying):
            return "Failed to create file \(url.path): \(underlying.localizedDescription)"
        case let .failedToCreateDirectory(url, underlying):
            return "Failed to create directory \(url.path): \(underlying.localizedDescription)"
        case let .failedToDeleteFile(url, underlying):
            return "Failed to delete file \(url.path): \(underlying.localizedDescription)"
        case let .failedToRenameFile(url, underlying):
            return "Failed to rename file \(url.path): \(underlying.localizedDescription)"
        case let .failedToDuplicateFile(url, underlying):
            return "Failed to duplicate file \(url.path): \(underlying.localizedDescription)"
        }
    }
}

actor WorkspaceFileSystemActor {
    private let fileManager = FileManager.default

    func ensureDirectoryExists(at directory: URL) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func loadWorkspaces(from workspaceFile: URL) throws -> [Workspace] {
        guard fileManager.fileExists(atPath: workspaceFile.path) else {
            return []
        }
        let data = try Data(contentsOf: workspaceFile)
        return try JSONDecoder().decode([Workspace].self, from: data)
    }

    func saveWorkspaces(_ workspaces: [Workspace], to workspaceFile: URL) throws {
        let data = try JSONEncoder().encode(workspaces)
        try data.write(to: workspaceFile, options: .atomic)
    }

    func createEmptyFile(at fileURL: URL) throws {
        try "".write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func createDirectory(at directoryURL: URL) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: false)
    }

    func trashItem(at url: URL) throws {
        try fileManager.trashItem(at: url, resultingItemURL: nil)
    }

    func moveItem(at source: URL, to destination: URL) throws {
        try fileManager.moveItem(at: source, to: destination)
    }

    func copyItem(at source: URL, to destination: URL) throws {
        try fileManager.copyItem(at: source, to: destination)
    }

    func loadDirectoryContents(at directory: URL) throws -> [WorkspaceFile] {
        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .isHiddenKey
        ]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: options
        )

        var files: [WorkspaceFile] = []
        files.reserveCapacity(urls.count)

        for fileURL in urls {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys) else { continue }
            let isHidden = resourceValues.isHidden ?? false
            if isHidden { continue }

            let file = WorkspaceFile(
                url: fileURL,
                isDirectory: resourceValues.isDirectory ?? false,
                isExpanded: false,
                children: [],
                isSelected: false,
                isOpen: false,
                modificationDate: resourceValues.contentModificationDate,
                fileSize: resourceValues.fileSize.map(Int64.init)
            )
            files.append(file)
        }

        return files.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
