import Foundation
import Combine

// MARK: - iCloud Sync Manager

/// Manages iCloud Document storage, monitors remote changes via NSMetadataQuery,
/// and coordinates file access with NSFileCoordinator.
@MainActor
public final class iCloudSyncManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var iCloudAvailable: Bool = false
    @Published public private(set) var iCloudContainerURL: URL?
    @Published public private(set) var syncedDocuments: [SyncedDocument] = []

    // MARK: - Types

    public struct SyncedDocument: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let fileURL: URL
        public let fileName: String
        public let modifiedAt: Date
        public let fileSize: Int64
        public let downloadStatus: DownloadStatus
        public let isUploading: Bool
        public let hasConflicts: Bool

        public init(
            id: UUID = UUID(),
            fileURL: URL,
            fileName: String,
            modifiedAt: Date,
            fileSize: Int64,
            downloadStatus: DownloadStatus = .current,
            isUploading: Bool = false,
            hasConflicts: Bool = false
        ) {
            self.id = id
            self.fileURL = fileURL
            self.fileName = fileName
            self.modifiedAt = modifiedAt
            self.fileSize = fileSize
            self.downloadStatus = downloadStatus
            self.isUploading = isUploading
            self.hasConflicts = hasConflicts
        }
    }

    public enum DownloadStatus: String, Sendable {
        case notDownloaded
        case downloading
        case current
    }

    // MARK: - Private Properties

    private var metadataQuery: NSMetadataQuery?
    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default
    private let syncStatusTracker: SyncStatusTracker
    private let networkMonitor: NetworkMonitor

    // MARK: - Constants

    private static let documentsSubdirectory = "Documents"
    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    // MARK: - Callbacks

    public var onDocumentUpdatedRemotely: ((URL) -> Void)?
    public var onConflictDetected: ((URL, [NSFileVersion]) -> Void)?

    // MARK: - Initialization

    public init(syncStatusTracker: SyncStatusTracker, networkMonitor: NetworkMonitor) {
        self.syncStatusTracker = syncStatusTracker
        self.networkMonitor = networkMonitor

        checkiCloudAvailability()
    }

    // MARK: - Public API

    /// Check if iCloud is available and set up the container URL.
    public func checkiCloudAvailability() {
        Task.detached { [weak self] in
            let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.iCloudAvailable = containerURL != nil
                self.iCloudContainerURL = containerURL

                if let containerURL {
                    let documentsURL = containerURL.appendingPathComponent(
                        Self.documentsSubdirectory, isDirectory: true
                    )
                    // Ensure Documents directory exists
                    try? self.fileManager.createDirectory(
                        at: documentsURL,
                        withIntermediateDirectories: true
                    )
                }
            }
        }
    }

    /// Start monitoring iCloud for document changes.
    public func startMonitoring() {
        guard iCloudAvailable else { return }

        stopMonitoring()

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.md' OR %K LIKE '*.markdown'",
                                       NSMetadataItemFSNameKey, NSMetadataItemFSNameKey)

        // Initial results gathered
        NotificationCenter.default.publisher(for: .NSMetadataQueryDidFinishGathering, object: query)
            .sink { [weak self] _ in
                self?.processQueryResults()
            }
            .store(in: &cancellables)

        // Results updated
        NotificationCenter.default.publisher(for: .NSMetadataQueryDidUpdate, object: query)
            .sink { [weak self] notification in
                self?.processQueryUpdate(notification)
            }
            .store(in: &cancellables)

        query.start()
        query.enableUpdates()
        metadataQuery = query
    }

    /// Stop monitoring iCloud for changes.
    public func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery?.disableUpdates()
        metadataQuery = nil
        cancellables.removeAll()
    }

    /// Move a local document to iCloud.
    public func moveToiCloud(localURL: URL) async throws -> URL {
        guard let containerURL = iCloudContainerURL else {
            throw SyncError.iCloudUnavailable
        }

        let documentsURL = containerURL.appendingPathComponent(
            Self.documentsSubdirectory, isDirectory: true
        )
        let destinationURL = documentsURL.appendingPathComponent(localURL.lastPathComponent)

        return try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            coordinator.coordinate(
                writingItemAt: localURL, options: .forMoving,
                writingItemAt: destinationURL, options: .forReplacing,
                error: &coordinatorError
            ) { sourceURL, destURL in
                do {
                    try self.fileManager.setUbiquitous(true, itemAt: sourceURL, destinationURL: destURL)
                    continuation.resume(returning: destURL)
                } catch {
                    continuation.resume(throwing: SyncError.moveFailed(error.localizedDescription))
                }
            }

            if let error = coordinatorError {
                continuation.resume(throwing: SyncError.coordinationFailed(error.localizedDescription))
            }
        }
    }

    /// Evict a document from local storage (keep only in iCloud).
    public func evictFromLocal(fileURL: URL) throws {
        try fileManager.evictUbiquitousItem(at: fileURL)
    }

    /// Download a document from iCloud to local storage.
    public func downloadFromiCloud(fileURL: URL) throws {
        try fileManager.startDownloadingUbiquitousItem(at: fileURL)
    }

    /// Read a file using coordinated access.
    public func coordinatedRead(at url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: SyncError.readFailed(error.localizedDescription))
                }
            }

            if let error = coordinatorError {
                continuation.resume(throwing: SyncError.coordinationFailed(error.localizedDescription))
            }
        }
    }

    /// Write data to a file using coordinated access.
    public func coordinatedWrite(data: Data, to url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { writeURL in
                do {
                    try data.write(to: writeURL, options: .atomic)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: SyncError.writeFailed(error.localizedDescription))
                }
            }

            if let error = coordinatorError {
                continuation.resume(throwing: SyncError.coordinationFailed(error.localizedDescription))
            }
        }
    }

    /// Resolve conflicts for a document by keeping the specified version.
    public func resolveConflicts(for url: URL, keepingCurrent: Bool) {
        guard let conflictVersions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) else {
            return
        }

        if keepingCurrent {
            // Remove all conflict versions, keep the current file
            for version in conflictVersions {
                version.isResolved = true
            }
            try? NSFileVersion.removeOtherVersionsOfItem(at: url)
        } else if let newestConflict = conflictVersions.sorted(by: { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }).first {
            // Replace current with the newest conflict version
            do {
                try newestConflict.replaceItem(at: url, options: .byMoving)
                for version in conflictVersions {
                    version.isResolved = true
                }
                try NSFileVersion.removeOtherVersionsOfItem(at: url)
            } catch {
                syncStatusTracker.markSyncFailed(error: error)
            }
        }
    }

    /// Get all conflict versions for a file.
    public func conflictVersions(for url: URL) -> [NSFileVersion] {
        return NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
    }

    // MARK: - Private Methods

    private func processQueryResults() {
        guard let query = metadataQuery else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }

        var documents: [SyncedDocument] = []

        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem else { continue }
            if let doc = syncedDocument(from: item) {
                documents.append(doc)
            }
        }

        syncedDocuments = documents
        syncStatusTracker.markSyncCompleted()
    }

    private func processQueryUpdate(_ notification: Notification) {
        guard let query = metadataQuery else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }

        // Process added items
        if let addedItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
            for item in addedItems {
                if let doc = syncedDocument(from: item) {
                    if !syncedDocuments.contains(where: { $0.fileURL == doc.fileURL }) {
                        syncedDocuments.append(doc)
                    }
                }
            }
        }

        // Process changed items
        if let changedItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] {
            for item in changedItems {
                guard let doc = syncedDocument(from: item) else { continue }

                if let index = syncedDocuments.firstIndex(where: { $0.fileURL == doc.fileURL }) {
                    syncedDocuments[index] = doc
                }

                // Check for conflicts
                if doc.hasConflicts, let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                    let versions = conflictVersions(for: url)
                    if !versions.isEmpty {
                        onConflictDetected?(url, versions)
                        syncStatusTracker.markConflict(documentID: doc.id)
                    }
                }

                // Notify of remote updates
                if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                    onDocumentUpdatedRemotely?(url)
                }
            }
        }

        // Process removed items
        if let removedItems = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] {
            let removedURLs = Set(removedItems.compactMap {
                $0.value(forAttribute: NSMetadataItemURLKey) as? URL
            })
            syncedDocuments.removeAll { removedURLs.contains($0.fileURL) }
        }
    }

    private func syncedDocument(from item: NSMetadataItem) -> SyncedDocument? {
        guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
            return nil
        }

        let fileName = item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? url.lastPathComponent
        let modDate = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date ?? Date()
        let fileSize = item.value(forAttribute: NSMetadataItemFSSizeKey) as? Int64 ?? 0

        // Determine download status
        let downloadStatus: DownloadStatus
        if let downloadingStatus = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
            switch downloadingStatus {
            case NSMetadataUbiquitousItemDownloadingStatusNotDownloaded:
                downloadStatus = .notDownloaded
            case NSMetadataUbiquitousItemDownloadingStatusDownloaded,
                 NSMetadataUbiquitousItemDownloadingStatusCurrent:
                downloadStatus = .current
            default:
                downloadStatus = .downloading
            }
        } else {
            downloadStatus = .current
        }

        let isUploading = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool ?? false
        let hasConflicts = item.value(forAttribute: NSMetadataUbiquitousItemHasUnresolvedConflictsKey) as? Bool ?? false

        return SyncedDocument(
            fileURL: url,
            fileName: fileName,
            modifiedAt: modDate,
            fileSize: fileSize,
            downloadStatus: downloadStatus,
            isUploading: isUploading,
            hasConflicts: hasConflicts
        )
    }
}

// MARK: - Sync Errors

public enum SyncError: LocalizedError {
    case iCloudUnavailable
    case moveFailed(String)
    case readFailed(String)
    case writeFailed(String)
    case coordinationFailed(String)
    case conflictResolutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud is not available. Please sign in to iCloud in System Settings."
        case .moveFailed(let detail):
            return "Failed to move document: \(detail)"
        case .readFailed(let detail):
            return "Failed to read document: \(detail)"
        case .writeFailed(let detail):
            return "Failed to write document: \(detail)"
        case .coordinationFailed(let detail):
            return "File coordination failed: \(detail)"
        case .conflictResolutionFailed(let detail):
            return "Conflict resolution failed: \(detail)"
        }
    }
}
