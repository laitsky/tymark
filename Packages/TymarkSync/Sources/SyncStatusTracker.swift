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

    // MARK: - Callbacks

    public var onStatusChange: ((SyncStatus) -> Void)?
    public var onConflictDetected: ((UUID) -> Void)?

    // MARK: - Initialization

    public init() {
        setupNetworkMonitoring()
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

    // MARK: - Private Methods

    private func setupNetworkMonitoring() {
        // Monitor network reachability
        NotificationCenter.default
            .publisher(for: .init("NSProcessInfoPowerStateDidChangeNotification"))
            .sink { [weak self] _ in
                self?.checkNetworkStatus()
            }
            .store(in: &cancellables)
    }

    private func checkNetworkStatus() {
        // Simplified network check
        // In production, use NWPathMonitor
    }
}

// MARK: - Conflict Resolver

public final class ConflictResolver: @unchecked Sendable {

    public struct Conflict {
        public let documentID: UUID
        public let localVersion: String
        public let remoteVersion: String
        public let localDate: Date
        public let remoteDate: Date
    }

    public enum ResolutionStrategy {
        case preferLocal
        case preferRemote
        case merge
        case askUser
    }

    public var resolutionStrategy: ResolutionStrategy = .askUser

    public func resolve(_ conflict: Conflict) -> String {
        switch resolutionStrategy {
        case .preferLocal:
            return conflict.localVersion
        case .preferRemote:
            return conflict.remoteVersion
        case .merge:
            return attemptMerge(conflict)
        case .askUser:
            // Return local by default, user will be prompted
            return conflict.localVersion
        }
    }

    private func attemptMerge(_ conflict: Conflict) -> String {
        // Two-way merge using longest common subsequence (LCS).
        // Without a common ancestor, we find shared lines via LCS,
        // interleave unique lines from each side, and mark true
        // conflicts with standard conflict markers.

        let localLines = conflict.localVersion.components(separatedBy: "\n")
        let remoteLines = conflict.remoteVersion.components(separatedBy: "\n")

        // Build LCS table
        let lcs = longestCommonSubsequence(localLines, remoteLines)

        var mergedLines: [String] = []
        var i = 0
        var j = 0

        for commonLine in lcs {
            // Collect local-only lines before this common line
            var localOnly: [String] = []
            while i < localLines.count && localLines[i] != commonLine {
                localOnly.append(localLines[i])
                i += 1
            }

            // Collect remote-only lines before this common line
            var remoteOnly: [String] = []
            while j < remoteLines.count && remoteLines[j] != commonLine {
                remoteOnly.append(remoteLines[j])
                j += 1
            }

            // If both sides have unique lines, mark as conflict
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
            i += 1 // skip past the common line in local
            j += 1 // skip past the common line in remote
        }

        // Handle remaining lines after the last common line
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

        // Backtrack to find the LCS
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
