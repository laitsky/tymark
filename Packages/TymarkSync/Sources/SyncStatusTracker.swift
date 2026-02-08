import Foundation
import Combine

// MARK: - Sync Status

public enum SyncStatus: Equatable {
    case synced
    case syncing
    case pendingUpload
    case pendingDownload
    case conflict
    case error(String)
    case offline

    public var isSynced: Bool {
        if case .synced = self { return true }
        return false
    }

    public var isPending: Bool {
        switch self {
        case .pendingUpload, .pendingDownload, .syncing:
            return true
        default:
            return false
        }
    }

    public var description: String {
        switch self {
        case .synced:
            return "Synced"
        case .syncing:
            return "Syncing..."
        case .pendingUpload:
            return "Upload pending"
        case .pendingDownload:
            return "Download pending"
        case .conflict:
            return "Conflict detected"
        case .error(let message):
            return "Error: \(message)"
        case .offline:
            return "Offline"
        }
    }

    public var systemImageName: String {
        switch self {
        case .synced:
            return "checkmark.icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .pendingUpload:
            return "icloud.and.arrow.up"
        case .pendingDownload:
            return "icloud.and.arrow.down"
        case .conflict:
            return "exclamationmark.icloud"
        case .error:
            return "xmark.icloud"
        case .offline:
            return "icloud.slash"
        }
    }
}

// MARK: - Sync Status Tracker

@MainActor
public final class SyncStatusTracker: ObservableObject {

    // MARK: - Published Properties

    @Published public var status: SyncStatus = .synced
    @Published public var lastSyncDate: Date?
    @Published public var isOffline: Bool = false
    @Published public var hasConflicts: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var pendingChanges: [UUID: Date] = [:]
    private weak var networkMonitor: NetworkMonitor?

    // MARK: - Callbacks

    public var onStatusChange: ((SyncStatus) -> Void)?
    public var onConflictDetected: ((UUID) -> Void)?

    // MARK: - Initialization

    public init() {}

    /// Connect to a NetworkMonitor for real connectivity tracking.
    public func configure(with networkMonitor: NetworkMonitor) {
        self.networkMonitor = networkMonitor

        networkMonitor.$isConnected
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self else { return }
                if isConnected {
                    self.goOnline()
                } else {
                    self.goOffline()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    public func markPendingChange(documentID: UUID) {
        pendingChanges[documentID] = Date()

        if !isOffline {
            status = .pendingUpload
        }

        onStatusChange?(status)
    }

    public func markSyncStarted() {
        status = .syncing
        onStatusChange?(status)
    }

    public func markSyncCompleted() {
        pendingChanges.removeAll()
        status = isOffline ? .offline : .synced
        lastSyncDate = Date()
        hasConflicts = false
        onStatusChange?(status)
    }

    public func markSyncFailed(error: Error) {
        status = .error(error.localizedDescription)
        onStatusChange?(status)
    }

    public func markConflict(documentID: UUID) {
        hasConflicts = true
        status = .conflict
        onConflictDetected?(documentID)
        onStatusChange?(status)
    }

    public func goOffline() {
        isOffline = true
        if !pendingChanges.isEmpty {
            status = .pendingUpload
        } else {
            status = .offline
        }
        onStatusChange?(status)
    }

    public func goOnline() {
        isOffline = false
        if !pendingChanges.isEmpty {
            status = .pendingUpload
        } else {
            status = .synced
        }
        onStatusChange?(status)
    }

    /// Formatted string for the last sync time.
    public var lastSyncDescription: String? {
        guard let date = lastSyncDate else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Conflict Resolver

@MainActor
public final class ConflictResolver {

    public struct Conflict {
        public let documentID: UUID
        public let localVersion: String
        public let remoteVersion: String
        public let localDate: Date
        public let remoteDate: Date

        public init(documentID: UUID, localVersion: String, remoteVersion: String, localDate: Date, remoteDate: Date) {
            self.documentID = documentID
            self.localVersion = localVersion
            self.remoteVersion = remoteVersion
            self.localDate = localDate
            self.remoteDate = remoteDate
        }
    }

    public enum ResolutionStrategy {
        case preferLocal
        case preferRemote
        case merge
        case askUser
    }

    public var resolutionStrategy: ResolutionStrategy = .askUser

    public init() {}

    public func resolve(_ conflict: Conflict) -> String {
        switch resolutionStrategy {
        case .preferLocal:
            return conflict.localVersion
        case .preferRemote:
            return conflict.remoteVersion
        case .merge:
            return attemptMerge(conflict)
        case .askUser:
            return conflict.localVersion
        }
    }

    private func attemptMerge(_ conflict: Conflict) -> String {
        let localLines = conflict.localVersion.components(separatedBy: "\n")
        let remoteLines = conflict.remoteVersion.components(separatedBy: "\n")

        let lcs = longestCommonSubsequence(localLines, remoteLines)

        var mergedLines: [String] = []
        var i = 0
        var j = 0

        for commonLine in lcs {
            var localOnly: [String] = []
            while i < localLines.count && localLines[i] != commonLine {
                localOnly.append(localLines[i])
                i += 1
            }

            var remoteOnly: [String] = []
            while j < remoteLines.count && remoteLines[j] != commonLine {
                remoteOnly.append(remoteLines[j])
                j += 1
            }

            if !localOnly.isEmpty && !remoteOnly.isEmpty {
                mergedLines.append("<<<<<<< LOCAL")
                mergedLines.append(contentsOf: localOnly)
                mergedLines.append("=======")
                mergedLines.append(contentsOf: remoteOnly)
                mergedLines.append(">>>>>>> REMOTE")
            } else {
                mergedLines.append(contentsOf: localOnly)
                mergedLines.append(contentsOf: remoteOnly)
            }

            mergedLines.append(commonLine)
            i += 1
            j += 1
        }

        var localTail: [String] = []
        while i < localLines.count {
            localTail.append(localLines[i])
            i += 1
        }
        var remoteTail: [String] = []
        while j < remoteLines.count {
            remoteTail.append(remoteLines[j])
            j += 1
        }

        if !localTail.isEmpty && !remoteTail.isEmpty {
            mergedLines.append("<<<<<<< LOCAL")
            mergedLines.append(contentsOf: localTail)
            mergedLines.append("=======")
            mergedLines.append(contentsOf: remoteTail)
            mergedLines.append(">>>>>>> REMOTE")
        } else {
            mergedLines.append(contentsOf: localTail)
            mergedLines.append(contentsOf: remoteTail)
        }

        return mergedLines.joined(separator: "\n")
    }

    private func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count
        guard m > 0, n > 0 else { return [] }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        var result: [String] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                result.append(a[i - 1])
                i -= 1
                j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        return result.reversed()
    }
}
