import XCTest
@testable import TymarkExport

final class TymarkExportTests: XCTestCase {
    func testExportManager() {
        let manager = ExportManager()
        XCTAssertFalse(manager.availableFormats().isEmpty)
    }

    func testHTMLExporter() {
        let exporter = HTMLExporter()
        XCTAssertEqual(exporter.fileExtension, "html")
    }
}
