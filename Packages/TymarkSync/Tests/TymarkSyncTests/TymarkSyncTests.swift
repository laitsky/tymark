import XCTest
@testable import TymarkSync

final class TymarkSyncTests: XCTestCase {
    func testSyncStatus() {
        let tracker = SyncStatusTracker()
        XCTAssertEqual(tracker.status, .synced)
    }

    func testDocumentMetadata() {
        let metadata = TymarkDocument.DocumentMetadata()
        XCTAssertNotNil(metadata.createdAt)
    }
}
