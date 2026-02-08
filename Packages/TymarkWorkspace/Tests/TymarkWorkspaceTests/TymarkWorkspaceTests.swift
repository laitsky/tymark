import XCTest
@testable import TymarkWorkspace

final class TymarkWorkspaceTests: XCTestCase {
    func testWorkspaceInitialization() {
        let workspace = Workspace(name: "Test")
        XCTAssertEqual(workspace.name, "Test")
    }

    func testFuzzySearch() {
        let engine = FuzzySearchEngine()
        // Test would go here
        XCTAssertTrue(true)
    }
}
