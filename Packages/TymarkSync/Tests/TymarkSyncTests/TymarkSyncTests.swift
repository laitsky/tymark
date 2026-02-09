#if canImport(XCTest)
import XCTest
@testable import TymarkSync

// MARK: - DocumentMetadata Tests

final class DocumentMetadataTests: XCTestCase {

    func testDefaultValues() {
        let beforeCreation = Date()
        let metadata = DocumentMetadata()
        let afterCreation = Date()

        XCTAssertNil(metadata.title)
        XCTAssertNil(metadata.author)
        XCTAssertEqual(metadata.tags, [])
        XCTAssertEqual(metadata.wordCount, 0)
        XCTAssertEqual(metadata.characterCount, 0)

        // createdAt and modifiedAt should be set to approximately now
        XCTAssertGreaterThanOrEqual(metadata.createdAt, beforeCreation)
        XCTAssertLessThanOrEqual(metadata.createdAt, afterCreation)
        XCTAssertGreaterThanOrEqual(metadata.modifiedAt, beforeCreation)
        XCTAssertLessThanOrEqual(metadata.modifiedAt, afterCreation)
    }

    func testCustomValues() {
        let created = Date(timeIntervalSince1970: 1_000_000)
        let modified = Date(timeIntervalSince1970: 2_000_000)
        let metadata = DocumentMetadata(
            title: "My Title",
            author: "Jane Doe",
            createdAt: created,
            modifiedAt: modified,
            tags: ["swift", "markdown"],
            wordCount: 150,
            characterCount: 800
        )

        XCTAssertEqual(metadata.title, "My Title")
        XCTAssertEqual(metadata.author, "Jane Doe")
        XCTAssertEqual(metadata.createdAt, created)
        XCTAssertEqual(metadata.modifiedAt, modified)
        XCTAssertEqual(metadata.tags, ["swift", "markdown"])
        XCTAssertEqual(metadata.wordCount, 150)
        XCTAssertEqual(metadata.characterCount, 800)
    }

    func testCodableRoundTrip() throws {
        let created = Date(timeIntervalSince1970: 1_000_000)
        let modified = Date(timeIntervalSince1970: 2_000_000)
        let original = DocumentMetadata(
            title: "Round Trip",
            author: "Author",
            createdAt: created,
            modifiedAt: modified,
            tags: ["test", "codable"],
            wordCount: 42,
            characterCount: 256
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DocumentMetadata.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testCodableRoundTripWithNilOptionals() throws {
        let metadata = DocumentMetadata(
            title: nil,
            author: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            modifiedAt: Date(timeIntervalSince1970: 0),
            tags: [],
            wordCount: 0,
            characterCount: 0
        )

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(DocumentMetadata.self, from: data)

        XCTAssertEqual(metadata, decoded)
        XCTAssertNil(decoded.title)
        XCTAssertNil(decoded.author)
    }

    func testEquatable() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let a = DocumentMetadata(title: "A", createdAt: date, modifiedAt: date, wordCount: 10)
        let b = DocumentMetadata(title: "A", createdAt: date, modifiedAt: date, wordCount: 10)
        let c = DocumentMetadata(title: "B", createdAt: date, modifiedAt: date, wordCount: 10)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - ExportFormat Tests

final class ExportFormatTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ExportFormat.allCases.count, 3)
    }

    func testAllCasesContents() {
        let cases = ExportFormat.allCases
        XCTAssertTrue(cases.contains(.html))
        XCTAssertTrue(cases.contains(.pdf))
        XCTAssertTrue(cases.contains(.docx))
    }

    func testFileExtensions() {
        XCTAssertEqual(ExportFormat.html.fileExtension, "html")
        XCTAssertEqual(ExportFormat.pdf.fileExtension, "pdf")
        XCTAssertEqual(ExportFormat.docx.fileExtension, "docx")
    }

    func testMimeTypes() {
        XCTAssertEqual(ExportFormat.html.mimeType, "text/html")
        XCTAssertEqual(ExportFormat.pdf.mimeType, "application/pdf")
        XCTAssertEqual(
            ExportFormat.docx.mimeType,
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
    }

    func testRawValues() {
        XCTAssertEqual(ExportFormat.html.rawValue, "HTML")
        XCTAssertEqual(ExportFormat.pdf.rawValue, "PDF")
        XCTAssertEqual(ExportFormat.docx.rawValue, "DOCX")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(ExportFormat(rawValue: "HTML"), .html)
        XCTAssertEqual(ExportFormat(rawValue: "PDF"), .pdf)
        XCTAssertEqual(ExportFormat(rawValue: "DOCX"), .docx)
        XCTAssertNil(ExportFormat(rawValue: "txt"))
    }
}

// MARK: - MarkdownContentHelpers Tests

final class MarkdownContentHelpersTests: XCTestCase {

    // MARK: extractTitle

    func testExtractTitleFromH1() {
        let content = """
        # My Document Title
        Some body text here.
        """
        let title = MarkdownContentHelpers.extractTitle(from: content)
        XCTAssertEqual(title, "My Document Title")
    }

    func testExtractTitleReturnsNilWithNoHeading() {
        let content = """
        Just some text.
        No headings anywhere.
        """
        let title = MarkdownContentHelpers.extractTitle(from: content)
        XCTAssertNil(title)
    }

    func testExtractTitleIgnoresH2AndBelow() {
        let content = """
        ## Second Level Heading
        ### Third Level Heading
        Some body text.
        """
        let title = MarkdownContentHelpers.extractTitle(from: content)
        XCTAssertNil(title)
    }

    func testExtractTitleReturnsFirstH1Only() {
        let content = """
        # First Title
        Some text.
        # Second Title
        More text.
        """
        let title = MarkdownContentHelpers.extractTitle(from: content)
        XCTAssertEqual(title, "First Title")
    }

    func testExtractTitleFromEmptyString() {
        let title = MarkdownContentHelpers.extractTitle(from: "")
        XCTAssertNil(title)
    }

    // MARK: extractHeadings

    func testExtractHeadingsAllLevels() {
        let content = """
        # Heading 1
        Some text.
        ## Heading 2
        More text.
        ### Heading 3
        #### Heading 4
        """
        let headings = MarkdownContentHelpers.extractHeadings(from: content)
        XCTAssertEqual(headings, ["Heading 1", "Heading 2", "Heading 3", "Heading 4"])
    }

    func testExtractHeadingsNoHeadings() {
        let content = """
        Just plain text.
        No markdown headings here.
        """
        let headings = MarkdownContentHelpers.extractHeadings(from: content)
        XCTAssertEqual(headings, [])
    }

    func testExtractHeadingsFromEmptyString() {
        let headings = MarkdownContentHelpers.extractHeadings(from: "")
        XCTAssertEqual(headings, [])
    }

    func testExtractHeadingsStripsHashes() {
        let content = "### Triple Hash Title"
        let headings = MarkdownContentHelpers.extractHeadings(from: content)
        XCTAssertEqual(headings, ["Triple Hash Title"])
    }

    // MARK: extractPreview

    func testExtractPreviewSkipsHeadingsAndEmptyLines() {
        let content = """
        # Title

        ## Subtitle

        First paragraph line.
        Second paragraph line.
        Third paragraph line.
        """
        let preview = MarkdownContentHelpers.extractPreview(from: content)
        XCTAssertEqual(preview, "First paragraph line. Second paragraph line. Third paragraph line.")
    }

    func testExtractPreviewLimitsToThreeLines() {
        let content = """
        Line one.
        Line two.
        Line three.
        Line four.
        Line five.
        """
        let preview = MarkdownContentHelpers.extractPreview(from: content)
        XCTAssertEqual(preview, "Line one. Line two. Line three.")
    }

    func testExtractPreviewSkipsSeparators() {
        let content = """
        ---
        First real line.
        ---
        Second real line.
        """
        let preview = MarkdownContentHelpers.extractPreview(from: content)
        XCTAssertEqual(preview, "First real line. Second real line.")
    }

    func testExtractPreviewFromEmptyString() {
        let preview = MarkdownContentHelpers.extractPreview(from: "")
        XCTAssertEqual(preview, "")
    }

    func testExtractPreviewFewerThanThreeLines() {
        let content = """
        # Title
        Only one content line.
        """
        let preview = MarkdownContentHelpers.extractPreview(from: content)
        XCTAssertEqual(preview, "Only one content line.")
    }
}

// MARK: - SyncStatus Tests

final class SyncStatusTests: XCTestCase {

    // MARK: isSynced

    func testIsSyncedForSynced() {
        XCTAssertTrue(SyncStatus.synced.isSynced)
    }

    func testIsSyncedForSyncing() {
        XCTAssertFalse(SyncStatus.syncing.isSynced)
    }

    func testIsSyncedForPendingUpload() {
        XCTAssertFalse(SyncStatus.pendingUpload.isSynced)
    }

    func testIsSyncedForPendingDownload() {
        XCTAssertFalse(SyncStatus.pendingDownload.isSynced)
    }

    func testIsSyncedForConflict() {
        XCTAssertFalse(SyncStatus.conflict.isSynced)
    }

    func testIsSyncedForError() {
        XCTAssertFalse(SyncStatus.error("fail").isSynced)
    }

    func testIsSyncedForOffline() {
        XCTAssertFalse(SyncStatus.offline.isSynced)
    }

    // MARK: isPending

    func testIsPendingForSynced() {
        XCTAssertFalse(SyncStatus.synced.isPending)
    }

    func testIsPendingForSyncing() {
        XCTAssertTrue(SyncStatus.syncing.isPending)
    }

    func testIsPendingForPendingUpload() {
        XCTAssertTrue(SyncStatus.pendingUpload.isPending)
    }

    func testIsPendingForPendingDownload() {
        XCTAssertTrue(SyncStatus.pendingDownload.isPending)
    }

    func testIsPendingForConflict() {
        XCTAssertFalse(SyncStatus.conflict.isPending)
    }

    func testIsPendingForError() {
        XCTAssertFalse(SyncStatus.error("fail").isPending)
    }

    func testIsPendingForOffline() {
        XCTAssertFalse(SyncStatus.offline.isPending)
    }

    // MARK: description

    func testDescriptionSynced() {
        XCTAssertEqual(SyncStatus.synced.description, "Synced")
    }

    func testDescriptionSyncing() {
        XCTAssertEqual(SyncStatus.syncing.description, "Syncing...")
    }

    func testDescriptionPendingUpload() {
        XCTAssertEqual(SyncStatus.pendingUpload.description, "Upload pending")
    }

    func testDescriptionPendingDownload() {
        XCTAssertEqual(SyncStatus.pendingDownload.description, "Download pending")
    }

    func testDescriptionConflict() {
        XCTAssertEqual(SyncStatus.conflict.description, "Conflict detected")
    }

    func testDescriptionError() {
        XCTAssertEqual(SyncStatus.error("Network timeout").description, "Error: Network timeout")
    }

    func testDescriptionOffline() {
        XCTAssertEqual(SyncStatus.offline.description, "Offline")
    }

    // MARK: systemImageName

    func testSystemImageNameSynced() {
        XCTAssertEqual(SyncStatus.synced.systemImageName, "checkmark.icloud")
    }

    func testSystemImageNameSyncing() {
        XCTAssertEqual(SyncStatus.syncing.systemImageName, "arrow.triangle.2.circlepath.icloud")
    }

    func testSystemImageNamePendingUpload() {
        XCTAssertEqual(SyncStatus.pendingUpload.systemImageName, "icloud.and.arrow.up")
    }

    func testSystemImageNamePendingDownload() {
        XCTAssertEqual(SyncStatus.pendingDownload.systemImageName, "icloud.and.arrow.down")
    }

    func testSystemImageNameConflict() {
        XCTAssertEqual(SyncStatus.conflict.systemImageName, "exclamationmark.icloud")
    }

    func testSystemImageNameError() {
        XCTAssertEqual(SyncStatus.error("any").systemImageName, "xmark.icloud")
    }

    func testSystemImageNameOffline() {
        XCTAssertEqual(SyncStatus.offline.systemImageName, "icloud.slash")
    }

    // MARK: Equatable

    func testEquatableMatchingErrors() {
        XCTAssertEqual(SyncStatus.error("same"), SyncStatus.error("same"))
    }

    func testEquatableDifferentErrors() {
        XCTAssertNotEqual(SyncStatus.error("a"), SyncStatus.error("b"))
    }

    func testEquatableDifferentCases() {
        XCTAssertNotEqual(SyncStatus.synced, SyncStatus.offline)
    }
}

// MARK: - SyncStatusTracker Tests

final class SyncStatusTrackerTests: XCTestCase {

    @MainActor
    func testInitialState() {
        let tracker = SyncStatusTracker()

        XCTAssertEqual(tracker.status, .synced)
        XCTAssertNil(tracker.lastSyncDate)
        XCTAssertFalse(tracker.isOffline)
        XCTAssertFalse(tracker.hasConflicts)
    }

    @MainActor
    func testMarkPendingChangeUpdatesStatus() {
        let tracker = SyncStatusTracker()
        let docID = UUID()

        tracker.markPendingChange(documentID: docID)

        XCTAssertEqual(tracker.status, .pendingUpload)
    }

    @MainActor
    func testMarkSyncStartedSetsStatusToSyncing() {
        let tracker = SyncStatusTracker()

        tracker.markSyncStarted()

        XCTAssertEqual(tracker.status, .syncing)
    }

    @MainActor
    func testMarkSyncCompletedFlow() {
        let tracker = SyncStatusTracker()
        let docID = UUID()

        tracker.markPendingChange(documentID: docID)
        XCTAssertEqual(tracker.status, .pendingUpload)

        tracker.markSyncStarted()
        XCTAssertEqual(tracker.status, .syncing)

        tracker.markSyncCompleted()
        XCTAssertEqual(tracker.status, .synced)
        XCTAssertNotNil(tracker.lastSyncDate)
        XCTAssertFalse(tracker.hasConflicts)
    }

    @MainActor
    func testMarkSyncCompletedSetsLastSyncDate() {
        let tracker = SyncStatusTracker()
        XCTAssertNil(tracker.lastSyncDate)

        let before = Date()
        tracker.markSyncCompleted()
        let after = Date()

        XCTAssertNotNil(tracker.lastSyncDate)
        XCTAssertGreaterThanOrEqual(tracker.lastSyncDate!, before)
        XCTAssertLessThanOrEqual(tracker.lastSyncDate!, after)
    }

    @MainActor
    func testMarkSyncFailedSetsErrorStatus() {
        let tracker = SyncStatusTracker()

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Something went wrong" }
        }

        tracker.markSyncFailed(error: TestError())

        XCTAssertEqual(tracker.status, .error("Something went wrong"))
    }

    @MainActor
    func testMarkConflictSetsHasConflicts() {
        let tracker = SyncStatusTracker()
        let docID = UUID()

        tracker.markConflict(documentID: docID)

        XCTAssertTrue(tracker.hasConflicts)
        XCTAssertEqual(tracker.status, .conflict)
    }

    @MainActor
    func testGoOfflineWithNoPendingChanges() {
        let tracker = SyncStatusTracker()

        tracker.goOffline()

        XCTAssertTrue(tracker.isOffline)
        XCTAssertEqual(tracker.status, .offline)
    }

    @MainActor
    func testGoOfflineWithPendingChangesStaysPendingUpload() {
        let tracker = SyncStatusTracker()
        let docID = UUID()

        tracker.markPendingChange(documentID: docID)
        tracker.goOffline()

        XCTAssertTrue(tracker.isOffline)
        XCTAssertEqual(tracker.status, .pendingUpload)
    }

    @MainActor
    func testGoOnlineFromOffline() {
        let tracker = SyncStatusTracker()

        tracker.goOffline()
        XCTAssertEqual(tracker.status, .offline)

        tracker.goOnline()
        XCTAssertFalse(tracker.isOffline)
        XCTAssertEqual(tracker.status, .synced)
    }

    @MainActor
    func testGoOnlineWithPendingChanges() {
        let tracker = SyncStatusTracker()
        let docID = UUID()

        tracker.markPendingChange(documentID: docID)
        tracker.goOffline()
        XCTAssertEqual(tracker.status, .pendingUpload)

        tracker.goOnline()
        XCTAssertFalse(tracker.isOffline)
        XCTAssertEqual(tracker.status, .pendingUpload)
    }

    @MainActor
    func testMarkSyncCompletedWhileOfflineSetsOfflineStatus() {
        let tracker = SyncStatusTracker()

        tracker.goOffline()
        tracker.markSyncCompleted()

        XCTAssertEqual(tracker.status, .offline)
        XCTAssertNotNil(tracker.lastSyncDate)
    }

    @MainActor
    func testMarkPendingChangeWhileOfflineDoesNotChangeStatus() {
        let tracker = SyncStatusTracker()

        tracker.goOffline()
        XCTAssertEqual(tracker.status, .offline)

        let docID = UUID()
        tracker.markPendingChange(documentID: docID)

        // When offline, markPendingChange does not update status (isOffline guard)
        XCTAssertEqual(tracker.status, .offline)
    }

    @MainActor
    func testLastSyncDescriptionNilWhenNoSync() {
        let tracker = SyncStatusTracker()
        XCTAssertNil(tracker.lastSyncDescription)
    }

    @MainActor
    func testLastSyncDescriptionAfterSync() {
        let tracker = SyncStatusTracker()
        tracker.markSyncCompleted()

        // After completing sync, lastSyncDescription should be a non-nil string
        XCTAssertNotNil(tracker.lastSyncDescription)
    }

    @MainActor
    func testOnStatusChangeCallback() {
        let tracker = SyncStatusTracker()
        var receivedStatuses: [SyncStatus] = []

        tracker.onStatusChange = { status in
            receivedStatuses.append(status)
        }

        tracker.markPendingChange(documentID: UUID())
        tracker.markSyncStarted()
        tracker.markSyncCompleted()

        XCTAssertEqual(receivedStatuses.count, 3)
        XCTAssertEqual(receivedStatuses[0], .pendingUpload)
        XCTAssertEqual(receivedStatuses[1], .syncing)
        XCTAssertEqual(receivedStatuses[2], .synced)
    }

    @MainActor
    func testOnConflictDetectedCallback() {
        let tracker = SyncStatusTracker()
        var detectedDocIDs: [UUID] = []

        tracker.onConflictDetected = { docID in
            detectedDocIDs.append(docID)
        }

        let docID = UUID()
        tracker.markConflict(documentID: docID)

        XCTAssertEqual(detectedDocIDs.count, 1)
        XCTAssertEqual(detectedDocIDs.first, docID)
    }

    @MainActor
    func testMarkSyncCompletedClearsConflicts() {
        let tracker = SyncStatusTracker()

        tracker.markConflict(documentID: UUID())
        XCTAssertTrue(tracker.hasConflicts)

        tracker.markSyncCompleted()
        XCTAssertFalse(tracker.hasConflicts)
    }
}

// MARK: - ConflictResolver Tests

final class ConflictResolverTests: XCTestCase {

    @MainActor
    private func makeConflict(
        local: String = "local content",
        remote: String = "remote content"
    ) -> ConflictResolver.Conflict {
        ConflictResolver.Conflict(
            documentID: UUID(),
            localVersion: local,
            remoteVersion: remote,
            localDate: Date(),
            remoteDate: Date()
        )
    }

    @MainActor
    func testPreferLocalReturnsLocalVersion() {
        let resolver = ConflictResolver()
        resolver.resolutionStrategy = .preferLocal

        let conflict = makeConflict(local: "my local text", remote: "their remote text")
        let result = resolver.resolve(conflict)

        XCTAssertEqual(result, "my local text")
    }

    @MainActor
    func testPreferRemoteReturnsRemoteVersion() {
        let resolver = ConflictResolver()
        resolver.resolutionStrategy = .preferRemote

        let conflict = makeConflict(local: "my local text", remote: "their remote text")
        let result = resolver.resolve(conflict)

        XCTAssertEqual(result, "their remote text")
    }

    @MainActor
    func testMergeIncludesConflictMarkers() {
        let resolver = ConflictResolver()
        resolver.resolutionStrategy = .merge

        let local = "shared line\nlocal only line\nshared end"
        let remote = "shared line\nremote only line\nshared end"
        let conflict = makeConflict(local: local, remote: remote)
        let result = resolver.resolve(conflict)

        XCTAssertTrue(result.contains("<<<<<<< LOCAL"))
        XCTAssertTrue(result.contains("======="))
        XCTAssertTrue(result.contains(">>>>>>> REMOTE"))
        XCTAssertTrue(result.contains("local only line"))
        XCTAssertTrue(result.contains("remote only line"))
        XCTAssertTrue(result.contains("shared line"))
        XCTAssertTrue(result.contains("shared end"))
    }

    @MainActor
    func testMergeWithIdenticalContent() {
        let resolver = ConflictResolver()
        resolver.resolutionStrategy = .merge

        let content = "line one\nline two\nline three"
        let conflict = makeConflict(local: content, remote: content)
        let result = resolver.resolve(conflict)

        // Identical content should merge without conflict markers
        XCTAssertFalse(result.contains("<<<<<<< LOCAL"))
        XCTAssertEqual(result, content)
    }

    @MainActor
    func testAskUserDefaultsToLocalVersion() {
        let resolver = ConflictResolver()
        // Default strategy is .askUser
        XCTAssertEqual(resolver.resolutionStrategy, .askUser)

        let conflict = makeConflict(local: "local version", remote: "remote version")
        let result = resolver.resolve(conflict)

        XCTAssertEqual(result, "local version")
    }

    @MainActor
    func testDefaultStrategyIsAskUser() {
        let resolver = ConflictResolver()
        // Verify the default without setting it
        let conflict = makeConflict()
        let result = resolver.resolve(conflict)

        XCTAssertEqual(result, "local content")
    }

    @MainActor
    func testMergeWithCompletelyDifferentContent() {
        let resolver = ConflictResolver()
        resolver.resolutionStrategy = .merge

        let conflict = makeConflict(
            local: "completely different local",
            remote: "entirely unique remote"
        )
        let result = resolver.resolve(conflict)

        // With no common lines, should produce conflict markers
        XCTAssertTrue(result.contains("<<<<<<< LOCAL"))
        XCTAssertTrue(result.contains(">>>>>>> REMOTE"))
    }

    @MainActor
    func testMergePreservesSharedLines() {
        let resolver = ConflictResolver()
        resolver.resolutionStrategy = .merge

        let local = "# Title\nLocal paragraph.\nShared footer."
        let remote = "# Title\nRemote paragraph.\nShared footer."
        let conflict = makeConflict(local: local, remote: remote)
        let result = resolver.resolve(conflict)

        // Shared lines should appear in the result
        XCTAssertTrue(result.contains("# Title"))
        XCTAssertTrue(result.contains("Shared footer."))
    }
}

#endif
