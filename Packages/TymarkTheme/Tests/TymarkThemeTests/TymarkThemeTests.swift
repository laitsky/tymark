import XCTest
@testable import TymarkTheme

final class TymarkThemeTests: XCTestCase {
    func testThemeInitialization() {
        let theme = BuiltInThemes.light
        XCTAssertEqual(theme.name, "Light")
    }

    func testThemeManager() {
        let manager = ThemeManager.shared
        XCTAssertFalse(manager.availableThemes.isEmpty)
    }

    func testColorHexConversion() {
        let color = CodableColor(red: 1, green: 0, blue: 0, alpha: 1)
        XCTAssertEqual(color.hexString, "#FF0000")
    }
}
