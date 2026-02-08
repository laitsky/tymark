import Foundation
import AppKit
import Combine

// MARK: - Workspace

public struct Workspace: Identifiable, Equatable, Codable {
    public let id: UUID
    public var name: String
    public var rootURL: URL?
    public var isExpanded: Bool
    public var openFiles: [WorkspaceFile]
    public var selectedFileID: UUID?
    public var recentFiles: [URL]

    public init(
        id: UUID = UUID(),
        name: String,
        rootURL: URL? = nil,
        isExpanded: Bool = true,
        openFiles: [WorkspaceFile] = [],
        selectedFileID: UUID? = nil,
        recentFiles: [URL] = []
    ) {
        self.id = id
        self.name = name
        self.rootURL = rootURL
        self.isExpanded = isExpanded
        self.openFiles = openFiles
        self.selectedFileID = selectedFileID
        self.recentFiles = recentFiles
    }
}

// MARK: - Workspace File

public struct WorkspaceFile: Identifiable, Equatable, Codable {
    public let id: UUID
    public var url: URL
    public var name: String
    public var isDirectory: Bool
    public var isExpanded: Bool
    public var children: [WorkspaceFile]
    public var isSelected: Bool
    public var isOpen: Bool
    public var modificationDate: Date?
    public var fileSize: Int64?

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        isDirectory: Bool = false,
        isExpanded: Bool = false,
        children: [WorkspaceFile] = [],
        isSelected: Bool = false,
        isOpen: Bool = false,
        modificationDate: Date? = nil,
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.isDirectory = isDirectory
        self.isExpanded = isExpanded
        self.children = children
        self.isSelected = isSelected
        self.isOpen = isOpen
        self.modificationDate = modificationDate
        self.fileSize = fileSize
    }

    public var fileExtension: String {
        return url.pathExtension
    }

    public var displayIcon: NSImage? {
        if isDirectory {
            return NSImage(named: NSImage.folderName)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Workspace Manager

@MainActor
public final class WorkspaceManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var workspaces: [Workspace] = []
    @Published public var currentWorkspace: Workspace?
    @Published public var selectedFiles: [WorkspaceFile] = []

    // MARK: - Private Properties

    private var fileMonitor: FileMonitor?
    private var cancellables = Set<AnyCancellable>()
    private let workspacesDirectory: URL

    // MARK: - Callbacks

    public var onFileSelected: ((WorkspaceFile) -> Void)?
    public var onFileOpen: ((WorkspaceFile) -> Void)?
    public var onFileCreate: ((URL) -> Void)?
    public var onFileDelete: ((URL) -> Void)?

    // MARK: - Initialization

    public init() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate Application Support directory")
        }
        self.workspacesDirectory = appSupport.appendingPathComponent("Tymark/Workspaces", isDirectory: true)

        loadWorkspaces()
        setupFileMonitoring()
    }

    // MARK: - Public API

    public func createWorkspace(name: String, at url: URL? = nil) -> Workspace {
        let workspace = Workspace(
            name: name,
            rootURL: url,
            openFiles: []
        )

        workspaces.append(workspace)
        saveWorkspaces()

        if currentWorkspace == nil {
            currentWorkspace = workspace
        }

        return workspace
    }

    public func openWorkspace(_ workspace: Workspace) {
        currentWorkspace = workspace

        // Refresh file tree
        if let rootURL = workspace.rootURL {
            refreshFileTree(for: workspace.id, rootURL: rootURL)
        }
    }

    public func closeWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
        saveWorkspaces()

        if currentWorkspace?.id == id {
            currentWorkspace = workspaces.first
        }
    }

    public func setWorkspaceRoot(_ url: URL, for workspaceID: UUID) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }

        workspaces[index].rootURL = url
        saveWorkspaces()

        // Refresh file tree
        refreshFileTree(for: workspaceID, rootURL: url)

        // Update file monitoring
        setupFileMonitoring()
    }

    public func refreshFileTree(for workspaceID: UUID, rootURL: URL) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }

        let fileTree = buildFileTree(from: rootURL)
        workspaces[index].openFiles = fileTree
    }

    public func expandDirectory(_ fileID: UUID, in workspaceID: UUID) {
        guard let workspaceIndex = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }

        func updateFileTree(_ files: inout [WorkspaceFile]) -> Bool {
            for i in files.indices {
                if files[i].id == fileID {
                    files[i].isExpanded.toggle()
                    if files[i].isExpanded && files[i].children.isEmpty {
                        // Load children
                        files[i].children = loadDirectoryContents(url: files[i].url)
                    }
                    return true
                }
                if updateFileTree(&files[i].children) {
                    return true
                }
            }
            return false
        }

        updateFileTree(&workspaces[workspaceIndex].openFiles)
    }

    public func selectFile(_ file: WorkspaceFile) {
        // Clear previous selection
        selectedFiles.forEach { file in
            updateFileSelection(fileID: file.id, isSelected: false)
        }

        // Set new selection
        selectedFiles = [file]
        updateFileSelection(fileID: file.id, isSelected: true)

        // Notify callback
        onFileSelected?(file)
    }

    public func openFile(_ file: WorkspaceFile) {
        guard !file.isDirectory else { return }

        // Mark as open
        updateFileOpenStatus(fileID: file.id, isOpen: true)

        // Add to recent files
        if var workspace = currentWorkspace {
            workspace.recentFiles.removeAll { $0 == file.url }
            workspace.recentFiles.insert(file.url, at: 0)
            if workspace.recentFiles.count > 10 {
                workspace.recentFiles.removeLast()
            }
            currentWorkspace = workspace
        }

        // Notify callback
        onFileOpen?(file)
    }

    public func createNewFile(in directory: URL, name: String) -> URL? {
        let fileURL = directory.appendingPathComponent(name)

        do {
            // Create empty file
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            onFileCreate?(fileURL)
            return fileURL
        } catch {
            print("Failed to create file: \(error)")
            return nil
        }
    }

    public func createNewDirectory(in directory: URL, name: String) -> URL? {
        let dirURL = directory.appendingPathComponent(name, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: false)
            onFileCreate?(dirURL)
            return dirURL
        } catch {
            print("Failed to create directory: \(error)")
            return nil
        }
    }

    public func deleteFile(_ file: WorkspaceFile) -> Bool {
        // Validate file is within workspace root
        if let workspace = currentWorkspace,
           let root = workspace.rootURL {
            guard file.url.path.hasPrefix(root.path) else {
                print("Cannot delete file outside workspace: \(file.url.path)")
                return false
            }
        }

        do {
            // Move to trash instead of permanent deletion
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            onFileDelete?(file.url)
            return true
        } catch {
            print("Failed to delete file: \(error)")
            return false
        }
    }

    public func renameFile(_ file: WorkspaceFile, to newName: String) -> URL? {
        let newURL = file.url.deletingLastPathComponent().appendingPathComponent(newName)

        do {
            try FileManager.default.moveItem(at: file.url, to: newURL)
            return newURL
        } catch {
            print("Failed to rename file: \(error)")
            return nil
        }
    }

    public func duplicateFile(_ file: WorkspaceFile) -> URL? {
        let baseName = file.url.deletingPathExtension().lastPathComponent
        let ext = file.url.pathExtension
        let newName = "\(baseName) Copy\(ext.isEmpty ? "" : ".\(ext)")"
        let newURL = file.url.deletingLastPathComponent().appendingPathComponent(newName)

        do {
            try FileManager.default.copyItem(at: file.url, to: newURL)
            onFileCreate?(newURL)
            return newURL
        } catch {
            print("Failed to duplicate file: \(error)")
            return nil
        }
    }

    // MARK: - Private Methods

    private func buildFileTree(from url: URL, depth: Int = 0) -> [WorkspaceFile] {
        guard depth < 10 else { return [] } // Prevent deep recursion

        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: options,
            errorHandler: nil
        ) else {
            return []
        }

        var files: [WorkspaceFile] = []

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)) else { continue }

            let isDirectory = resourceValues.isDirectory ?? false
            let isHidden = resourceValues.isHidden ?? false

            if isHidden { continue }

            let file = WorkspaceFile(
                url: fileURL,
                isDirectory: isDirectory,
                isExpanded: false,
                children: [],
                isSelected: false,
                isOpen: false,
                modificationDate: resourceValues.contentModificationDate,
                fileSize: resourceValues.fileSize.map(Int64.init)
            )

            files.append(file)

            // Don't descend into directories at this level
            if isDirectory {
                enumerator.skipDescendants()
            }
        }

        return files.sorted { file1, file2 in
            if file1.isDirectory != file2.isDirectory {
                return file1.isDirectory // Directories first
            }
            return file1.name.localizedCaseInsensitiveCompare(file2.name) == .orderedAscending
        }
    }

    private func loadDirectoryContents(url: URL) -> [WorkspaceFile] {
        return buildFileTree(from: url, depth: 0)
    }

    private func updateFileSelection(fileID: UUID, isSelected: Bool) {
        func updateInFiles(_ files: inout [WorkspaceFile]) -> Bool {
            for i in files.indices {
                if files[i].id == fileID {
                    files[i].isSelected = isSelected
                    return true
                }
                if updateInFiles(&files[i].children) {
                    return true
                }
            }
            return false
        }

        if var workspace = currentWorkspace {
            updateInFiles(&workspace.openFiles)
            currentWorkspace = workspace
        }
    }

    private func updateFileOpenStatus(fileID: UUID, isOpen: Bool) {
        func updateInFiles(_ files: inout [WorkspaceFile]) -> Bool {
            for i in files.indices {
                if files[i].id == fileID {
                    files[i].isOpen = isOpen
                    return true
                }
                if updateInFiles(&files[i].children) {
                    return true
                }
            }
            return false
        }

        if var workspace = currentWorkspace {
            updateInFiles(&workspace.openFiles)
            currentWorkspace = workspace
        }
    }

    private func loadWorkspaces() {
        try? FileManager.default.createDirectory(
            at: workspacesDirectory,
            withIntermediateDirectories: true
        )

        let workspaceFile = workspacesDirectory.appendingPathComponent("workspaces.json")

        guard let data = try? Data(contentsOf: workspaceFile),
              let loadedWorkspaces = try? JSONDecoder().decode([Workspace].self, from: data) else {
            return
        }

        workspaces = loadedWorkspaces

        // Restore current workspace
        if let savedID = UserDefaults.standard.string(forKey: "currentWorkspaceID"),
           let uuid = UUID(uuidString: savedID),
           let workspace = workspaces.first(where: { $0.id == uuid }) {
            currentWorkspace = workspace
        }
    }

    private func saveWorkspaces() {
        let workspaceFile = workspacesDirectory.appendingPathComponent("workspaces.json")

        if let data = try? JSONEncoder().encode(workspaces) {
            try? data.write(to: workspaceFile)
        }

        // Save current workspace ID
        if let id = currentWorkspace?.id.uuidString {
            UserDefaults.standard.set(id, forKey: "currentWorkspaceID")
        }
    }

    private func setupFileMonitoring() {
        guard let rootURL = currentWorkspace?.rootURL else { return }
        let monitor = FileMonitor(directory: rootURL)
        monitor?.onChange = { [weak self] in
            self?.handleFileSystemChange()
        }
        fileMonitor = monitor
    }

    private func handleFileSystemChange() {
        guard let workspace = currentWorkspace,
              let rootURL = workspace.rootURL else { return }

        refreshFileTree(for: workspace.id, rootURL: rootURL)
    }
}

// MARK: - File Monitor

private final class FileMonitor {
    private let source: DispatchSourceFileSystemObject
    private let fileDescriptor: Int32
    var onChange: (() -> Void)?

    init?(directory: URL) {
        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        self.fileDescriptor = fd

        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: DispatchQueue.main
        )
        self.source = dispatchSource

        dispatchSource.setEventHandler { [weak self] in
            self?.onChange?()
        }

        dispatchSource.setCancelHandler {
            close(fd)
        }

        dispatchSource.resume()
    }

    deinit {
        source.cancel()
    }
}
