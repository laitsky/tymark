import Foundation
import AppKit

// MARK: - Workspace

public struct Workspace: Identifiable, Equatable, Codable, Sendable {
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

public struct WorkspaceFile: Identifiable, Equatable, Codable, Sendable {
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
    @Published public private(set) var lastError: WorkspaceManagerError?

    // MARK: - Private Properties

    private var fileMonitor: FileMonitor?
    private var saveTask: Task<Void, Never>?
    private let workspacesDirectory: URL
    private let fileSystem = WorkspaceFileSystemActor()

    // MARK: - Callbacks

    public var onFileSelected: ((WorkspaceFile) -> Void)?
    public var onFileOpen: ((WorkspaceFile) -> Void)?
    public var onFileCreate: ((URL) -> Void)?
    public var onFileDelete: ((URL) -> Void)?
    public var onError: ((WorkspaceManagerError) -> Void)?

    // MARK: - Initialization

    public init() {
        self.workspacesDirectory = Self.tymarkApplicationSupportDirectory(appending: "Workspaces")

        Task { [weak self] in
            await self?.loadWorkspaces()
            self?.setupFileMonitoring()
        }
    }

    deinit {
        saveTask?.cancel()
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
        if currentWorkspace?.id == workspaceID {
            currentWorkspace = workspaces[index]
        }
        saveWorkspaces()

        // Refresh file tree
        refreshFileTree(for: workspaceID, rootURL: url)

        // Update file monitoring
        setupFileMonitoring()
    }

    public func refreshFileTree(for workspaceID: UUID, rootURL: URL) {
        guard workspaces.contains(where: { $0.id == workspaceID }) else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                let fileTree = try await fileSystem.loadDirectoryContents(at: rootURL)
                guard let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
                workspaces[index].openFiles = fileTree
                if currentWorkspace?.id == workspaceID {
                    currentWorkspace = workspaces[index]
                }
            } catch {
                reportError(.failedToEnumerateDirectory(rootURL, error))
            }
        }
    }

    public func expandDirectory(_ fileID: UUID, in workspaceID: UUID) {
        guard let workspaceIndex = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }

        var directoryToLoad: URL?

        func updateFileTree(_ files: inout [WorkspaceFile]) -> Bool {
            for i in files.indices {
                if files[i].id == fileID {
                    files[i].isExpanded.toggle()
                    if files[i].isExpanded && files[i].children.isEmpty {
                        directoryToLoad = files[i].url
                    }
                    return true
                }
                if updateFileTree(&files[i].children) {
                    return true
                }
            }
            return false
        }

        _ = updateFileTree(&workspaces[workspaceIndex].openFiles)
        if currentWorkspace?.id == workspaceID {
            currentWorkspace = workspaces[workspaceIndex]
        }

        guard let url = directoryToLoad else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let children = try await fileSystem.loadDirectoryContents(at: url)
                applyLoadedChildren(children, forDirectoryID: fileID, in: workspaceID)
            } catch {
                reportError(.failedToEnumerateDirectory(url, error))
            }
        }
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
            if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
                workspaces[index].recentFiles = workspace.recentFiles
            }
            currentWorkspace = workspace
            saveWorkspaces()
        }

        // Notify callback
        onFileOpen?(file)
    }

    public func createNewFile(in directory: URL, name: String) async -> URL? {
        let fileURL = directory.appendingPathComponent(name)

        do {
            try await fileSystem.createEmptyFile(at: fileURL)
            onFileCreate?(fileURL)
            return fileURL
        } catch {
            reportError(.failedToCreateFile(fileURL, error))
            return nil
        }
    }

    public func createNewDirectory(in directory: URL, name: String) async -> URL? {
        let dirURL = directory.appendingPathComponent(name, isDirectory: true)

        do {
            try await fileSystem.createDirectory(at: dirURL)
            onFileCreate?(dirURL)
            return dirURL
        } catch {
            reportError(.failedToCreateDirectory(dirURL, error))
            return nil
        }
    }

    public func deleteFile(_ file: WorkspaceFile) async -> Bool {
        // Validate file is within workspace root
        if let workspace = currentWorkspace,
           let root = workspace.rootURL {
            guard file.url.path.hasPrefix(root.path) else {
                reportError(.failedToDeleteFile(
                    file.url,
                    NSError(
                        domain: "WorkspaceManager",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot delete file outside workspace root"]
                    )
                ))
                return false
            }
        }

        do {
            // Move to trash instead of permanent deletion
            try await fileSystem.trashItem(at: file.url)
            onFileDelete?(file.url)
            return true
        } catch {
            reportError(.failedToDeleteFile(file.url, error))
            return false
        }
    }

    public func renameFile(_ file: WorkspaceFile, to newName: String) async -> URL? {
        let newURL = file.url.deletingLastPathComponent().appendingPathComponent(newName)

        do {
            try await fileSystem.moveItem(at: file.url, to: newURL)
            return newURL
        } catch {
            reportError(.failedToRenameFile(file.url, error))
            return nil
        }
    }

    public func duplicateFile(_ file: WorkspaceFile) async -> URL? {
        let baseName = file.url.deletingPathExtension().lastPathComponent
        let ext = file.url.pathExtension
        let newName = "\(baseName) Copy\(ext.isEmpty ? "" : ".\(ext)")"
        let newURL = file.url.deletingLastPathComponent().appendingPathComponent(newName)

        do {
            try await fileSystem.copyItem(at: file.url, to: newURL)
            onFileCreate?(newURL)
            return newURL
        } catch {
            reportError(.failedToDuplicateFile(file.url, error))
            return nil
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

    private func reportError(_ error: WorkspaceManagerError) {
        lastError = error
        onError?(error)
    }

    private func applyLoadedChildren(_ children: [WorkspaceFile], forDirectoryID fileID: UUID, in workspaceID: UUID) {
        guard let workspaceIndex = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }

        func apply(_ files: inout [WorkspaceFile]) -> Bool {
            for index in files.indices {
                if files[index].id == fileID {
                    files[index].children = children
                    return true
                }
                if apply(&files[index].children) {
                    return true
                }
            }
            return false
        }

        _ = apply(&workspaces[workspaceIndex].openFiles)
        if currentWorkspace?.id == workspaceID {
            currentWorkspace = workspaces[workspaceIndex]
        }
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
            _ = updateInFiles(&workspace.openFiles)
            currentWorkspace = workspace
            if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
                workspaces[index].openFiles = workspace.openFiles
            }
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
            _ = updateInFiles(&workspace.openFiles)
            currentWorkspace = workspace
            if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
                workspaces[index].openFiles = workspace.openFiles
            }
        }
    }

    private func loadWorkspaces() async {
        let workspaceFile = workspacesDirectory.appendingPathComponent("workspaces.json")
        do {
            try await fileSystem.ensureDirectoryExists(at: workspacesDirectory)
            workspaces = try await fileSystem.loadWorkspaces(from: workspaceFile)
        } catch {
            reportError(.failedToLoadWorkspaces(workspaceFile, error))
            workspaces = []
        }

        // Restore current workspace from persisted ID.
        if let savedID = UserDefaults.standard.string(forKey: "currentWorkspaceID"),
           let uuid = UUID(uuidString: savedID),
           let workspace = workspaces.first(where: { $0.id == uuid }) {
            currentWorkspace = workspace
        } else {
            currentWorkspace = workspaces.first
        }
    }

    private func saveWorkspaces() {
        let workspaceFile = workspacesDirectory.appendingPathComponent("workspaces.json")
        let snapshot = workspaces
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            do {
                try Task.checkCancellation()
                try await fileSystem.ensureDirectoryExists(at: workspacesDirectory)
                try Task.checkCancellation()
                try await fileSystem.saveWorkspaces(snapshot, to: workspaceFile)
            } catch is CancellationError {
                return
            } catch {
                reportError(.failedToSaveWorkspaces(workspaceFile, error))
            }
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
