import XCTest
@testable import TymarkTheme

// MARK: - Built-In Themes Tests

final class BuiltInThemesTests: XCTestCase {

    func testAllThemesContainsSixThemes() {
        XCTAssertEqual(BuiltInThemes.allThemes.count, 6)
    }

    func testLightThemeNameAndIdentifier() {
        let theme = BuiltInThemes.light
        XCTAssertEqual(theme.name, "Light")
        XCTAssertEqual(theme.identifier, "light")
        XCTAssertTrue(theme.isBuiltIn)
    }

    func testDarkThemeNameAndIdentifier() {
        let theme = BuiltInThemes.dark
        XCTAssertEqual(theme.name, "Dark")
        XCTAssertEqual(theme.identifier, "dark")
        XCTAssertTrue(theme.isBuiltIn)
    }

    func testSepiaThemeNameAndIdentifier() {
        let theme = BuiltInThemes.sepia
        XCTAssertEqual(theme.name, "Sepia")
        XCTAssertEqual(theme.identifier, "sepia")
        XCTAssertTrue(theme.isBuiltIn)
    }

    func testNordThemeNameAndIdentifier() {
        let theme = BuiltInThemes.nord
        XCTAssertEqual(theme.name, "Nord")
        XCTAssertEqual(theme.identifier, "nord")
        XCTAssertTrue(theme.isBuiltIn)
    }

    func testSolarizedLightThemeNameAndIdentifier() {
        let theme = BuiltInThemes.solarizedLight
        XCTAssertEqual(theme.name, "Solarized Light")
        XCTAssertEqual(theme.identifier, "solarized-light")
        XCTAssertTrue(theme.isBuiltIn)
    }

    func testSolarizedDarkThemeNameAndIdentifier() {
        let theme = BuiltInThemes.solarizedDark
        XCTAssertEqual(theme.name, "Solarized Dark")
        XCTAssertEqual(theme.identifier, "solarized-dark")
        XCTAssertTrue(theme.isBuiltIn)
    }

    func testAllBuiltInThemesAreMarkedBuiltIn() {
        for theme in BuiltInThemes.allThemes {
            XCTAssertTrue(theme.isBuiltIn, "Theme \(theme.name) should be marked as built-in")
        }
    }

    func testAllBuiltInThemesHaveUniqueIdentifiers() {
        let identifiers = BuiltInThemes.allThemes.map { $0.identifier }
        let uniqueIdentifiers = Set(identifiers)
        XCTAssertEqual(identifiers.count, uniqueIdentifiers.count, "Built-in themes should have unique identifiers")
    }

    func testAllBuiltInThemesHaveUniqueNames() {
        let names = BuiltInThemes.allThemes.map { $0.name }
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "Built-in themes should have unique names")
    }

    func testAllBuiltInThemesHaveNonEmptyNamesAndIdentifiers() {
        for theme in BuiltInThemes.allThemes {
            XCTAssertFalse(theme.name.isEmpty, "Theme name should not be empty")
            XCTAssertFalse(theme.identifier.isEmpty, "Theme identifier should not be empty")
        }
    }

    func testAllBuiltInThemesPassValidation() {
        for theme in BuiltInThemes.allThemes {
            XCTAssertNoThrow(try ThemeParser.validate(theme), "Built-in theme \(theme.name) should pass validation")
        }
    }

    func testAllThemesArrayOrder() {
        let themes = BuiltInThemes.allThemes
        XCTAssertEqual(themes[0].identifier, "light")
        XCTAssertEqual(themes[1].identifier, "dark")
        XCTAssertEqual(themes[2].identifier, "sepia")
        XCTAssertEqual(themes[3].identifier, "nord")
        XCTAssertEqual(themes[4].identifier, "solarized-light")
        XCTAssertEqual(themes[5].identifier, "solarized-dark")
    }
}

// MARK: - CodableColor Tests

final class CodableColorTests: XCTestCase {

    // MARK: - Initialization

    func testInitWithRGBA() {
        let color = CodableColor(red: 0.5, green: 0.6, blue: 0.7, alpha: 0.8)
        XCTAssertEqual(color.red, 0.5)
        XCTAssertEqual(color.green, 0.6)
        XCTAssertEqual(color.blue, 0.7)
        XCTAssertEqual(color.alpha, 0.8)
    }

    func testInitWithDefaultAlpha() {
        let color = CodableColor(red: 0.1, green: 0.2, blue: 0.3)
        XCTAssertEqual(color.alpha, 1.0)
    }

    func testInitFromNSColor() {
        let nsColor = NSColor(srgbRed: 0.25, green: 0.5, blue: 0.75, alpha: 1.0)
        let color = CodableColor(color: nsColor)
        XCTAssertEqual(color.red, 0.25, accuracy: 0.01)
        XCTAssertEqual(color.green, 0.5, accuracy: 0.01)
        XCTAssertEqual(color.blue, 0.75, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 1.0, accuracy: 0.01)
    }

    // MARK: - NSColor Round-Trip

    func testNSColorRoundTrip() {
        let original = CodableColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.5)
        let nsColor = original.nsColor
        let roundTripped = CodableColor(color: nsColor)
        XCTAssertEqual(roundTripped.red, original.red, accuracy: 0.01)
        XCTAssertEqual(roundTripped.green, original.green, accuracy: 0.01)
        XCTAssertEqual(roundTripped.blue, original.blue, accuracy: 0.01)
        XCTAssertEqual(roundTripped.alpha, original.alpha, accuracy: 0.01)
    }

    func testNSColorRoundTripBlack() {
        let black = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
        let nsColor = black.nsColor
        let roundTripped = CodableColor(color: nsColor)
        XCTAssertEqual(roundTripped.red, 0, accuracy: 0.01)
        XCTAssertEqual(roundTripped.green, 0, accuracy: 0.01)
        XCTAssertEqual(roundTripped.blue, 0, accuracy: 0.01)
        XCTAssertEqual(roundTripped.alpha, 1, accuracy: 0.01)
    }

    func testNSColorRoundTripWhite() {
        let white = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
        let nsColor = white.nsColor
        let roundTripped = CodableColor(color: nsColor)
        XCTAssertEqual(roundTripped.red, 1, accuracy: 0.01)
        XCTAssertEqual(roundTripped.green, 1, accuracy: 0.01)
        XCTAssertEqual(roundTripped.blue, 1, accuracy: 0.01)
        XCTAssertEqual(roundTripped.alpha, 1, accuracy: 0.01)
    }

    // MARK: - Hex Conversion (6-char)

    func testHexStringPureRed() {
        let color = CodableColor(red: 1, green: 0, blue: 0, alpha: 1)
        XCTAssertEqual(color.hexString, "#FF0000")
    }

    func testHexStringPureGreen() {
        let color = CodableColor(red: 0, green: 1, blue: 0, alpha: 1)
        XCTAssertEqual(color.hexString, "#00FF00")
    }

    func testHexStringPureBlue() {
        let color = CodableColor(red: 0, green: 0, blue: 1, alpha: 1)
        XCTAssertEqual(color.hexString, "#0000FF")
    }

    func testHexStringBlack() {
        let color = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
        XCTAssertEqual(color.hexString, "#000000")
    }

    func testHexStringWhite() {
        let color = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
        XCTAssertEqual(color.hexString, "#FFFFFF")
    }

    // MARK: - Hex Conversion (8-char with alpha)

    func testHexStringWithAlphaFullOpacity() {
        let color = CodableColor(red: 1, green: 0, blue: 0, alpha: 1)
        XCTAssertEqual(color.hexStringWithAlpha, "#FF0000FF")
    }

    func testHexStringWithAlphaHalfOpacity() {
        let color = CodableColor(red: 0, green: 0, blue: 1, alpha: 0.5)
        let hex = color.hexStringWithAlpha
        // alpha 0.5 * 255 = 127.5, truncated to 127 = 0x7F
        XCTAssertTrue(hex.hasPrefix("#0000FF"), "Hex should start with #0000FF, got \(hex)")
        // Alpha byte should be approximately 0x7F or 0x80
        let alphaHex = String(hex.suffix(2))
        let alphaValue = UInt8(alphaHex, radix: 16) ?? 0
        XCTAssertTrue(alphaValue >= 0x7F && alphaValue <= 0x80, "Alpha byte should be ~0x7F or 0x80, got \(alphaHex)")
    }

    func testHexStringWithAlphaZeroOpacity() {
        let color = CodableColor(red: 1, green: 1, blue: 1, alpha: 0)
        XCTAssertEqual(color.hexStringWithAlpha, "#FFFFFF00")
    }

    // MARK: - fromHex (6-char)

    func testFromHex6CharRed() {
        let color = CodableColor.fromHex("#FF0000")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(color!.green, 0.0, accuracy: 0.01)
        XCTAssertEqual(color!.blue, 0.0, accuracy: 0.01)
        XCTAssertEqual(color!.alpha, 1.0, accuracy: 0.01)
    }

    func testFromHex6CharGreen() {
        let color = CodableColor.fromHex("#00FF00")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.green, 1.0, accuracy: 0.01)
    }

    func testFromHex6CharBlue() {
        let color = CodableColor.fromHex("#0000FF")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.blue, 1.0, accuracy: 0.01)
    }

    func testFromHex6CharWithoutHash() {
        let color = CodableColor.fromHex("FF0000")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.red, 1.0, accuracy: 0.01)
    }

    func testFromHex6CharLowercase() {
        let color = CodableColor.fromHex("#ff8800")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(color!.green, CGFloat(0x88) / 255.0, accuracy: 0.01)
        XCTAssertEqual(color!.blue, 0.0, accuracy: 0.01)
    }

    func testFromHexDefaultsAlphaTo1ForSixChar() {
        let color = CodableColor.fromHex("#ABCDEF")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.alpha, 1.0, accuracy: 0.01)
    }

    // MARK: - fromHex (8-char)

    func testFromHex8CharFullAlpha() {
        let color = CodableColor.fromHex("#FF0000FF")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(color!.green, 0.0, accuracy: 0.01)
        XCTAssertEqual(color!.blue, 0.0, accuracy: 0.01)
        XCTAssertEqual(color!.alpha, 1.0, accuracy: 0.01)
    }

    func testFromHex8CharHalfAlpha() {
        let color = CodableColor.fromHex("#00FF0080")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.green, 1.0, accuracy: 0.01)
        XCTAssertEqual(color!.alpha, CGFloat(0x80) / 255.0, accuracy: 0.01)
    }

    func testFromHex8CharZeroAlpha() {
        let color = CodableColor.fromHex("#0000FF00")
        XCTAssertNotNil(color)
        XCTAssertEqual(color!.blue, 1.0, accuracy: 0.01)
        XCTAssertEqual(color!.alpha, 0.0, accuracy: 0.01)
    }

    // MARK: - fromHex (invalid)

    func testFromHexInvalidLength() {
        XCTAssertNil(CodableColor.fromHex("#FFF"))
        XCTAssertNil(CodableColor.fromHex("#FFFFF"))
        XCTAssertNil(CodableColor.fromHex("#FFFFFFF"))
        XCTAssertNil(CodableColor.fromHex("#FFFFFFFFF"))
    }

    func testFromHexInvalidCharacters() {
        XCTAssertNil(CodableColor.fromHex("#GGGGGG"))
        XCTAssertNil(CodableColor.fromHex("#ZZZZZZ"))
    }

    func testFromHexEmptyString() {
        XCTAssertNil(CodableColor.fromHex(""))
        XCTAssertNil(CodableColor.fromHex("#"))
    }

    // MARK: - Hex Round-Trip

    func testHexRoundTrip6Char() {
        let original = CodableColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1.0)
        let hex = original.hexString
        let restored = CodableColor.fromHex(hex)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored!.red, original.red, accuracy: 0.01)
        XCTAssertEqual(restored!.green, original.green, accuracy: 0.01)
        XCTAssertEqual(restored!.blue, original.blue, accuracy: 0.01)
    }

    func testHexRoundTrip8Char() {
        let original = CodableColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let hex = original.hexStringWithAlpha
        let restored = CodableColor.fromHex(hex)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored!.red, original.red, accuracy: 0.01)
        XCTAssertEqual(restored!.green, original.green, accuracy: 0.01)
        XCTAssertEqual(restored!.blue, original.blue, accuracy: 0.01)
        XCTAssertEqual(restored!.alpha, original.alpha, accuracy: 0.01)
    }

    // MARK: - withAlphaComponent

    func testWithAlphaComponent() {
        let color = CodableColor(red: 1, green: 0, blue: 0, alpha: 1)
        let modified = color.withAlphaComponent(0.5)
        XCTAssertEqual(modified.red, 1)
        XCTAssertEqual(modified.green, 0)
        XCTAssertEqual(modified.blue, 0)
        XCTAssertEqual(modified.alpha, 0.5)
    }

    func testWithAlphaComponentPreservesRGB() {
        let color = CodableColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.9)
        let modified = color.withAlphaComponent(0.1)
        XCTAssertEqual(modified.red, 0.1)
        XCTAssertEqual(modified.green, 0.2)
        XCTAssertEqual(modified.blue, 0.3)
        XCTAssertEqual(modified.alpha, 0.1)
    }

    // MARK: - Equatable

    func testColorEquality() {
        let a = CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let b = CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        XCTAssertEqual(a, b)
    }

    func testColorInequalityRed() {
        let a = CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let b = CodableColor(red: 0.6, green: 0.5, blue: 0.5, alpha: 1.0)
        XCTAssertNotEqual(a, b)
    }

    func testColorInequalityAlpha() {
        let a = CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let b = CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Codable

    func testColorCodableRoundTrip() throws {
        let original = CodableColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.9)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableColor.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - CodableFont Tests

final class CodableFontTests: XCTestCase {

    // MARK: - Initialization

    func testFontInitWithDefaults() {
        let font = CodableFont(family: "Helvetica", size: 14)
        XCTAssertEqual(font.family, "Helvetica")
        XCTAssertEqual(font.size, 14)
        XCTAssertEqual(font.weight, "Regular")
        XCTAssertFalse(font.isItalic)
    }

    func testFontInitWithAllParameters() {
        let font = CodableFont(family: "Times", size: 16, weight: "Bold", isItalic: true)
        XCTAssertEqual(font.family, "Times")
        XCTAssertEqual(font.size, 16)
        XCTAssertEqual(font.weight, "Bold")
        XCTAssertTrue(font.isItalic)
    }

    // MARK: - NSFont Generation

    func testNSFontGenerationReturnsNonNil() {
        let font = CodableFont(family: "Helvetica", size: 14)
        let nsFont = font.nsFont
        XCTAssertEqual(nsFont.pointSize, 14)
    }

    func testNSFontFallbackForUnknownFamily() {
        let font = CodableFont(family: "NonExistentFontFamily12345", size: 12)
        let nsFont = font.nsFont
        // Should fall back to system font
        XCTAssertEqual(nsFont.pointSize, 12)
    }

    func testNSFontPreservesSize() {
        let sizes: [CGFloat] = [10, 12, 14, 16, 18, 24, 36]
        for size in sizes {
            let font = CodableFont(family: "Helvetica", size: size)
            XCTAssertEqual(font.nsFont.pointSize, size, "Font size \(size) should be preserved")
        }
    }

    // MARK: - withWeight

    func testWithWeightBold() {
        let font = CodableFont(family: "Helvetica", size: 14)
        let bold = font.withWeight(.bold)
        XCTAssertEqual(bold.family, "Helvetica")
        XCTAssertEqual(bold.size, 14)
        XCTAssertEqual(bold.weight, "Bold")
        XCTAssertFalse(bold.isItalic)
    }

    func testWithWeightLight() {
        let font = CodableFont(family: "Helvetica", size: 14)
        let light = font.withWeight(.light)
        XCTAssertEqual(light.weight, "Light")
    }

    func testWithWeightSemibold() {
        let font = CodableFont(family: "Helvetica", size: 14)
        let semi = font.withWeight(.semibold)
        XCTAssertEqual(semi.weight, "Semibold")
    }

    func testWithWeightMedium() {
        let font = CodableFont(family: "Helvetica", size: 14)
        let medium = font.withWeight(.medium)
        XCTAssertEqual(medium.weight, "Medium")
    }

    func testWithWeightHeavy() {
        let font = CodableFont(family: "Helvetica", size: 14)
        let heavy = font.withWeight(.heavy)
        XCTAssertEqual(heavy.weight, "Heavy")
    }

    func testWithWeightBlack() {
        let font = CodableFont(family: "Helvetica", size: 14)
        let black = font.withWeight(.black)
        XCTAssertEqual(black.weight, "Black")
    }

    func testWithWeightThin() {
        let font = CodableFont(family: "Helvetica", size: 14)
        let thin = font.withWeight(.thin)
        XCTAssertEqual(thin.weight, "Thin")
    }

    func testWithWeightUltraLight() {
        let font = CodableFont(family: "Helvetica", size: 14)
        let ultraLight = font.withWeight(.ultraLight)
        XCTAssertEqual(ultraLight.weight, "UltraLight")
    }

    func testWithWeightRegular() {
        let font = CodableFont(family: "Helvetica", size: 14, weight: "Bold")
        let regular = font.withWeight(.regular)
        XCTAssertEqual(regular.weight, "Regular")
    }

    func testWithWeightPreservesOtherProperties() {
        let font = CodableFont(family: "Times", size: 18, weight: "Regular", isItalic: true)
        let bold = font.withWeight(.bold)
        XCTAssertEqual(bold.family, "Times")
        XCTAssertEqual(bold.size, 18)
        XCTAssertTrue(bold.isItalic)
    }

    // MARK: - withStyle

    func testWithStyleItalic() {
        let font = CodableFont(family: "Helvetica", size: 14)
        let italic = font.withStyle(.italicFontMask)
        XCTAssertTrue(italic.isItalic)
        XCTAssertEqual(italic.family, "Helvetica")
        XCTAssertEqual(italic.size, 14)
        XCTAssertEqual(italic.weight, "Regular")
    }

    func testWithStyleNonItalic() {
        let font = CodableFont(family: "Helvetica", size: 14, weight: "Regular", isItalic: true)
        let nonItalic = font.withStyle([])
        XCTAssertFalse(nonItalic.isItalic)
    }

    func testWithStylePreservesOtherProperties() {
        let font = CodableFont(family: "Courier", size: 12, weight: "Bold")
        let italic = font.withStyle(.italicFontMask)
        XCTAssertEqual(italic.family, "Courier")
        XCTAssertEqual(italic.size, 12)
        XCTAssertEqual(italic.weight, "Bold")
    }

    // MARK: - Equatable

    func testFontEquality() {
        let a = CodableFont(family: "Helvetica", size: 14, weight: "Regular", isItalic: false)
        let b = CodableFont(family: "Helvetica", size: 14, weight: "Regular", isItalic: false)
        XCTAssertEqual(a, b)
    }

    func testFontInequalityFamily() {
        let a = CodableFont(family: "Helvetica", size: 14)
        let b = CodableFont(family: "Times", size: 14)
        XCTAssertNotEqual(a, b)
    }

    func testFontInequalitySize() {
        let a = CodableFont(family: "Helvetica", size: 14)
        let b = CodableFont(family: "Helvetica", size: 16)
        XCTAssertNotEqual(a, b)
    }

    func testFontInequalityWeight() {
        let a = CodableFont(family: "Helvetica", size: 14, weight: "Regular")
        let b = CodableFont(family: "Helvetica", size: 14, weight: "Bold")
        XCTAssertNotEqual(a, b)
    }

    func testFontInequalityItalic() {
        let a = CodableFont(family: "Helvetica", size: 14, weight: "Regular", isItalic: false)
        let b = CodableFont(family: "Helvetica", size: 14, weight: "Regular", isItalic: true)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Codable

    func testFontCodableRoundTrip() throws {
        let original = CodableFont(family: "Courier", size: 13, weight: "Bold", isItalic: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableFont.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - ThemeFonts Tests

final class ThemeFontsTests: XCTestCase {

    func testHeadingDefaultsToBoldBody() {
        let body = CodableFont(family: "Helvetica", size: 14, weight: "Regular", isItalic: false)
        let code = CodableFont(family: "Courier", size: 13)
        let fonts = ThemeFonts(body: body, code: code)

        XCTAssertEqual(fonts.heading.family, "Helvetica")
        XCTAssertEqual(fonts.heading.size, 14)
        XCTAssertEqual(fonts.heading.weight, "Bold")
        XCTAssertFalse(fonts.heading.isItalic)
    }

    func testQuoteDefaultsToItalicBody() {
        let body = CodableFont(family: "Helvetica", size: 14, weight: "Regular", isItalic: false)
        let code = CodableFont(family: "Courier", size: 13)
        let fonts = ThemeFonts(body: body, code: code)

        XCTAssertEqual(fonts.quote.family, "Helvetica")
        XCTAssertEqual(fonts.quote.size, 14)
        XCTAssertEqual(fonts.quote.weight, "Regular")
        XCTAssertTrue(fonts.quote.isItalic)
    }

    func testExplicitHeadingOverridesDefault() {
        let body = CodableFont(family: "Helvetica", size: 14)
        let heading = CodableFont(family: "Georgia", size: 20, weight: "Semibold")
        let code = CodableFont(family: "Courier", size: 13)
        let fonts = ThemeFonts(body: body, heading: heading, code: code)

        XCTAssertEqual(fonts.heading.family, "Georgia")
        XCTAssertEqual(fonts.heading.size, 20)
        XCTAssertEqual(fonts.heading.weight, "Semibold")
    }

    func testExplicitQuoteOverridesDefault() {
        let body = CodableFont(family: "Helvetica", size: 14)
        let code = CodableFont(family: "Courier", size: 13)
        let quote = CodableFont(family: "Palatino", size: 15, weight: "Light", isItalic: true)
        let fonts = ThemeFonts(body: body, code: code, quote: quote)

        XCTAssertEqual(fonts.quote.family, "Palatino")
        XCTAssertEqual(fonts.quote.size, 15)
        XCTAssertEqual(fonts.quote.weight, "Light")
        XCTAssertTrue(fonts.quote.isItalic)
    }

    func testThemeFontsEquality() {
        let body = CodableFont(family: "Helvetica", size: 14)
        let code = CodableFont(family: "Courier", size: 13)
        let a = ThemeFonts(body: body, code: code)
        let b = ThemeFonts(body: body, code: code)
        XCTAssertEqual(a, b)
    }

    func testThemeFontsCodableRoundTrip() throws {
        let body = CodableFont(family: "Helvetica", size: 14)
        let code = CodableFont(family: "Courier", size: 13)
        let original = ThemeFonts(body: body, code: code)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemeFonts.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - ThemeSpacing Tests

final class ThemeSpacingTests: XCTestCase {

    func testDefaultValues() {
        let spacing = ThemeSpacing()
        XCTAssertEqual(spacing.paragraphSpacing, 8)
        XCTAssertEqual(spacing.lineHeight, 1.6)
        XCTAssertEqual(spacing.headingSpacingTop, 24)
        XCTAssertEqual(spacing.headingSpacingBottom, 12)
        XCTAssertEqual(spacing.listIndentation, 24)
        XCTAssertEqual(spacing.blockquoteIndentation, 16)
        XCTAssertEqual(spacing.codeBlockPadding, 12)
    }

    func testDefaultPageMargins() {
        let spacing = ThemeSpacing()
        XCTAssertEqual(spacing.pageMargins.top, 20)
        XCTAssertEqual(spacing.pageMargins.left, 20)
        XCTAssertEqual(spacing.pageMargins.bottom, 20)
        XCTAssertEqual(spacing.pageMargins.right, 20)
    }

    func testCustomValues() {
        let spacing = ThemeSpacing(
            paragraphSpacing: 16,
            lineHeight: 2.0,
            headingSpacingTop: 32,
            headingSpacingBottom: 16,
            listIndentation: 32,
            blockquoteIndentation: 24,
            codeBlockPadding: 16,
            pageMargins: NSEdgeInsets(top: 30, left: 40, bottom: 30, right: 40)
        )
        XCTAssertEqual(spacing.paragraphSpacing, 16)
        XCTAssertEqual(spacing.lineHeight, 2.0)
        XCTAssertEqual(spacing.headingSpacingTop, 32)
        XCTAssertEqual(spacing.headingSpacingBottom, 16)
        XCTAssertEqual(spacing.listIndentation, 32)
        XCTAssertEqual(spacing.blockquoteIndentation, 24)
        XCTAssertEqual(spacing.codeBlockPadding, 16)
        XCTAssertEqual(spacing.pageMargins.top, 30)
        XCTAssertEqual(spacing.pageMargins.left, 40)
        XCTAssertEqual(spacing.pageMargins.bottom, 30)
        XCTAssertEqual(spacing.pageMargins.right, 40)
    }

    func testEquality() {
        let a = ThemeSpacing()
        let b = ThemeSpacing()
        XCTAssertEqual(a, b)
    }

    func testInequalityParagraphSpacing() {
        let a = ThemeSpacing()
        let b = ThemeSpacing(paragraphSpacing: 16)
        XCTAssertNotEqual(a, b)
    }

    func testInequalityLineHeight() {
        let a = ThemeSpacing()
        let b = ThemeSpacing(lineHeight: 2.0)
        XCTAssertNotEqual(a, b)
    }

    func testInequalityPageMargins() {
        let a = ThemeSpacing()
        let b = ThemeSpacing(pageMargins: NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        XCTAssertNotEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let original = ThemeSpacing(
            paragraphSpacing: 10,
            lineHeight: 1.8,
            headingSpacingTop: 28,
            headingSpacingBottom: 14,
            listIndentation: 20,
            blockquoteIndentation: 18,
            codeBlockPadding: 14,
            pageMargins: NSEdgeInsets(top: 25, left: 30, bottom: 25, right: 30)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemeSpacing.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testDefaultSpacingCodableRoundTrip() throws {
        let original = ThemeSpacing()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemeSpacing.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - EditorSettings Tests

final class EditorSettingsTests: XCTestCase {

    func testDefaultValues() {
        let settings = EditorSettings()
        XCTAssertFalse(settings.showLineNumbers)
        XCTAssertFalse(settings.showInvisibles)
        XCTAssertTrue(settings.wrapLines)
        XCTAssertEqual(settings.tabWidth, 4)
        XCTAssertTrue(settings.useSpacesForTabs)
        XCTAssertFalse(settings.focusMode)
        XCTAssertFalse(settings.typewriterMode)
    }

    func testCustomValues() {
        let settings = EditorSettings(
            showLineNumbers: true,
            showInvisibles: true,
            wrapLines: false,
            tabWidth: 2,
            useSpacesForTabs: false,
            focusMode: true,
            typewriterMode: true
        )
        XCTAssertTrue(settings.showLineNumbers)
        XCTAssertTrue(settings.showInvisibles)
        XCTAssertFalse(settings.wrapLines)
        XCTAssertEqual(settings.tabWidth, 2)
        XCTAssertFalse(settings.useSpacesForTabs)
        XCTAssertTrue(settings.focusMode)
        XCTAssertTrue(settings.typewriterMode)
    }

    func testEquality() {
        let a = EditorSettings()
        let b = EditorSettings()
        XCTAssertEqual(a, b)
    }

    func testInequality() {
        let a = EditorSettings()
        let b = EditorSettings(showLineNumbers: true)
        XCTAssertNotEqual(a, b)
    }

    func testInequalityTabWidth() {
        let a = EditorSettings()
        let b = EditorSettings(tabWidth: 8)
        XCTAssertNotEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let original = EditorSettings(
            showLineNumbers: true,
            showInvisibles: true,
            wrapLines: false,
            tabWidth: 2,
            useSpacesForTabs: false,
            focusMode: true,
            typewriterMode: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EditorSettings.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testDefaultSettingsCodableRoundTrip() throws {
        let original = EditorSettings()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EditorSettings.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - Theme Tests

final class ThemeTests: XCTestCase {

    // MARK: - Helpers

    private func makeTestColors() -> ThemeColors {
        return ThemeColors(
            background: CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
            text: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
            secondaryText: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
            accent: CodableColor(red: 0, green: 0.5, blue: 1, alpha: 1),
            link: CodableColor(red: 0, green: 0.5, blue: 1, alpha: 1),
            codeBackground: CodableColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
            codeText: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
            heading: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
            quoteBorder: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1),
            quoteText: CodableColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1),
            listMarker: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
            syntaxHidden: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.3),
            selection: CodableColor(red: 0, green: 0.5, blue: 1, alpha: 0.3),
            cursor: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
            sidebarBackground: CodableColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
            sidebarText: CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
        )
    }

    private func makeTestFonts() -> ThemeFonts {
        return ThemeFonts(
            body: CodableFont(family: "Helvetica", size: 14),
            code: CodableFont(family: "Courier", size: 13)
        )
    }

    private func makeTestTheme(
        name: String = "Test",
        identifier: String = "test",
        isBuiltIn: Bool = false
    ) -> Theme {
        return Theme(
            name: name,
            identifier: identifier,
            isBuiltIn: isBuiltIn,
            colors: makeTestColors(),
            fonts: makeTestFonts()
        )
    }

    // MARK: - Initialization

    func testThemeInitialization() {
        let theme = makeTestTheme()
        XCTAssertEqual(theme.name, "Test")
        XCTAssertEqual(theme.identifier, "test")
        XCTAssertFalse(theme.isBuiltIn)
    }

    func testThemeHasUniqueID() {
        let theme1 = makeTestTheme()
        let theme2 = makeTestTheme()
        XCTAssertNotEqual(theme1.id, theme2.id)
    }

    func testThemeDefaultSpacingAndEditor() {
        let theme = makeTestTheme()
        XCTAssertEqual(theme.spacing, ThemeSpacing())
        XCTAssertEqual(theme.editor, EditorSettings())
    }

    // MARK: - Equatable

    func testEqualityByIdentifierNameColorsAndMore() {
        let colors = makeTestColors()
        let fonts = makeTestFonts()
        let spacing = ThemeSpacing()
        let editor = EditorSettings()

        let a = Theme(name: "Test", identifier: "test", colors: colors, fonts: fonts, spacing: spacing, editor: editor)
        let b = Theme(name: "Test", identifier: "test", colors: colors, fonts: fonts, spacing: spacing, editor: editor)

        // Different UUIDs but equal by content
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(a, b)
    }

    func testEqualityIgnoresID() {
        let colors = makeTestColors()
        let fonts = makeTestFonts()
        let a = Theme(id: UUID(), name: "Test", identifier: "test", colors: colors, fonts: fonts)
        let b = Theme(id: UUID(), name: "Test", identifier: "test", colors: colors, fonts: fonts)
        XCTAssertEqual(a, b)
    }

    func testEqualityIgnoresIsBuiltIn() {
        let colors = makeTestColors()
        let fonts = makeTestFonts()
        let a = Theme(name: "Test", identifier: "test", isBuiltIn: true, colors: colors, fonts: fonts)
        let b = Theme(name: "Test", identifier: "test", isBuiltIn: false, colors: colors, fonts: fonts)
        XCTAssertEqual(a, b)
    }

    func testInequalityByIdentifier() {
        let a = makeTestTheme(identifier: "test-a")
        let b = makeTestTheme(identifier: "test-b")
        XCTAssertNotEqual(a, b)
    }

    func testInequalityByName() {
        let a = makeTestTheme(name: "Alpha")
        let b = makeTestTheme(name: "Beta")
        XCTAssertNotEqual(a, b)
    }

    func testInequalityByColors() {
        var colorsA = makeTestColors()
        var colorsB = makeTestColors()
        colorsB.background = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)

        let fontsA = makeTestFonts()

        let a = Theme(name: "Test", identifier: "test", colors: colorsA, fonts: fontsA)
        let b = Theme(name: "Test", identifier: "test", colors: colorsB, fonts: fontsA)
        XCTAssertNotEqual(a, b)
    }

    func testInequalityByEditor() {
        let colors = makeTestColors()
        let fonts = makeTestFonts()
        let a = Theme(name: "Test", identifier: "test", colors: colors, fonts: fonts, editor: EditorSettings())
        let b = Theme(name: "Test", identifier: "test", colors: colors, fonts: fonts, editor: EditorSettings(tabWidth: 8))
        XCTAssertNotEqual(a, b)
    }

    func testInequalityBySpacing() {
        let colors = makeTestColors()
        let fonts = makeTestFonts()
        let a = Theme(name: "Test", identifier: "test", colors: colors, fonts: fonts, spacing: ThemeSpacing())
        let b = Theme(name: "Test", identifier: "test", colors: colors, fonts: fonts, spacing: ThemeSpacing(paragraphSpacing: 99))
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashable

    func testHashableConsistency() {
        let a = makeTestTheme(name: "Test", identifier: "test")
        let b = makeTestTheme(name: "Test", identifier: "test")
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashableInSet() {
        let a = makeTestTheme(name: "Test", identifier: "test")
        let b = makeTestTheme(name: "Test", identifier: "test")
        let set: Set<Theme> = [a, b]
        // Since they hash the same and are equal, set should have 1 element
        XCTAssertEqual(set.count, 1)
    }

    func testHashableDifferentThemesInSet() {
        let a = makeTestTheme(name: "Alpha", identifier: "alpha")
        let b = makeTestTheme(name: "Beta", identifier: "beta")
        let set: Set<Theme> = [a, b]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Codable Round-Trip

    func testThemeCodableRoundTrip() throws {
        let original = makeTestTheme()
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Theme.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.identifier, original.identifier)
        XCTAssertEqual(decoded.isBuiltIn, original.isBuiltIn)
        XCTAssertEqual(decoded.colors, original.colors)
        XCTAssertEqual(decoded.fonts, original.fonts)
        XCTAssertEqual(decoded.spacing, original.spacing)
        XCTAssertEqual(decoded.editor, original.editor)
        XCTAssertEqual(decoded.id, original.id)
    }

    func testBuiltInThemeCodableRoundTrip() throws {
        let original = BuiltInThemes.light
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Theme.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.identifier, original.identifier)
        XCTAssertEqual(decoded.isBuiltIn, original.isBuiltIn)
        XCTAssertEqual(decoded.colors, original.colors)
        XCTAssertEqual(decoded.fonts, original.fonts)
        XCTAssertEqual(decoded.spacing, original.spacing)
        XCTAssertEqual(decoded.editor, original.editor)
    }

    func testAllBuiltInThemesCodableRoundTrip() throws {
        for theme in BuiltInThemes.allThemes {
            let data = try JSONEncoder().encode(theme)
            let decoded = try JSONDecoder().decode(Theme.self, from: data)
            XCTAssertEqual(decoded.name, theme.name, "Round-trip failed for theme \(theme.name)")
            XCTAssertEqual(decoded.identifier, theme.identifier, "Round-trip failed for theme \(theme.name)")
            XCTAssertEqual(decoded.colors, theme.colors, "Round-trip failed for theme \(theme.name)")
            XCTAssertEqual(decoded.fonts, theme.fonts, "Round-trip failed for theme \(theme.name)")
            XCTAssertEqual(decoded.spacing, theme.spacing, "Round-trip failed for theme \(theme.name)")
            XCTAssertEqual(decoded.editor, theme.editor, "Round-trip failed for theme \(theme.name)")
        }
    }

    func testThemeWithCustomSpacingAndEditorCodableRoundTrip() throws {
        let original = Theme(
            name: "Custom",
            identifier: "custom",
            colors: makeTestColors(),
            fonts: makeTestFonts(),
            spacing: ThemeSpacing(paragraphSpacing: 12, lineHeight: 1.8),
            editor: EditorSettings(showLineNumbers: true, tabWidth: 2)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Theme.self, from: data)
        XCTAssertEqual(decoded.spacing, original.spacing)
        XCTAssertEqual(decoded.editor, original.editor)
    }
}

// MARK: - ThemeColors Tests

final class ThemeColorsTests: XCTestCase {

    func testThemeColorsHas16Properties() {
        let colors = ThemeColors(
            background: CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
            text: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
            secondaryText: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
            accent: CodableColor(red: 0, green: 0.5, blue: 1, alpha: 1),
            link: CodableColor(red: 0, green: 0.5, blue: 1, alpha: 1),
            codeBackground: CodableColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
            codeText: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
            heading: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
            quoteBorder: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1),
            quoteText: CodableColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1),
            listMarker: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
            syntaxHidden: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.3),
            selection: CodableColor(red: 0, green: 0.5, blue: 1, alpha: 0.3),
            cursor: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
            sidebarBackground: CodableColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
            sidebarText: CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
        )

        // Verify each field is accessible and has the expected value
        XCTAssertEqual(colors.background.red, 1)
        XCTAssertEqual(colors.text.red, 0)
        XCTAssertEqual(colors.secondaryText.red, 0.5)
        XCTAssertEqual(colors.accent.green, 0.5)
        XCTAssertEqual(colors.link.blue, 1)
        XCTAssertEqual(colors.codeBackground.red, 0.95)
        XCTAssertEqual(colors.codeText.red, 0)
        XCTAssertEqual(colors.heading.red, 0)
        XCTAssertEqual(colors.quoteBorder.red, 0.8)
        XCTAssertEqual(colors.quoteText.red, 0.4)
        XCTAssertEqual(colors.listMarker.red, 0.5)
        XCTAssertEqual(colors.syntaxHidden.alpha, 0.3)
        XCTAssertEqual(colors.selection.alpha, 0.3)
        XCTAssertEqual(colors.cursor.red, 0)
        XCTAssertEqual(colors.sidebarBackground.red, 0.95)
        XCTAssertEqual(colors.sidebarText.red, 0)
    }

    func testThemeColorsEquality() {
        let white = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
        let black = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
        let gray = CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)

        let a = ThemeColors(
            background: white, text: black, secondaryText: gray,
            accent: gray, link: gray, codeBackground: gray,
            codeText: black, heading: black, quoteBorder: gray,
            quoteText: gray, listMarker: gray, syntaxHidden: gray,
            selection: gray, cursor: black, sidebarBackground: gray,
            sidebarText: black
        )
        let b = ThemeColors(
            background: white, text: black, secondaryText: gray,
            accent: gray, link: gray, codeBackground: gray,
            codeText: black, heading: black, quoteBorder: gray,
            quoteText: gray, listMarker: gray, syntaxHidden: gray,
            selection: gray, cursor: black, sidebarBackground: gray,
            sidebarText: black
        )
        XCTAssertEqual(a, b)
    }

    func testThemeColorsCodableRoundTrip() throws {
        let original = BuiltInThemes.dark.colors
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemeColors.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - ThemeParser Tests

final class ThemeParserTests: XCTestCase {

    // MARK: - Helpers

    private func makeValidTheme() -> Theme {
        return Theme(
            name: "Test Theme",
            identifier: "test-theme",
            isBuiltIn: false,
            colors: ThemeColors(
                background: CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
                text: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
                secondaryText: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
                accent: CodableColor(red: 0, green: 0.5, blue: 1, alpha: 1),
                link: CodableColor(red: 0, green: 0.5, blue: 1, alpha: 1),
                codeBackground: CodableColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
                codeText: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
                heading: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
                quoteBorder: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1),
                quoteText: CodableColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1),
                listMarker: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
                syntaxHidden: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.3),
                selection: CodableColor(red: 0, green: 0.5, blue: 1, alpha: 0.3),
                cursor: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
                sidebarBackground: CodableColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
                sidebarText: CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
            ),
            fonts: ThemeFonts(
                body: CodableFont(family: "Helvetica", size: 14),
                code: CodableFont(family: "Courier", size: 13)
            )
        )
    }

    // MARK: - Validation: Valid Theme

    func testValidateValidTheme() {
        let theme = makeValidTheme()
        XCTAssertNoThrow(try ThemeParser.validate(theme))
    }

    func testValidateAllBuiltInThemes() {
        for theme in BuiltInThemes.allThemes {
            XCTAssertNoThrow(try ThemeParser.validate(theme), "Validation failed for \(theme.name)")
        }
    }

    // MARK: - Validation: Empty Name

    func testValidateEmptyNameThrows() {
        var theme = makeValidTheme()
        theme.name = ""
        XCTAssertThrowsError(try ThemeParser.validate(theme)) { error in
            guard let parseError = error as? ThemeParser.ParseError else {
                XCTFail("Expected ParseError, got \(error)")
                return
            }
            if case .missingRequiredField(let field) = parseError {
                XCTAssertEqual(field, "name")
            } else {
                XCTFail("Expected missingRequiredField(name), got \(parseError)")
            }
        }
    }

    // MARK: - Validation: Empty Identifier

    func testValidateEmptyIdentifierThrows() {
        var theme = makeValidTheme()
        theme.identifier = ""
        XCTAssertThrowsError(try ThemeParser.validate(theme)) { error in
            guard let parseError = error as? ThemeParser.ParseError else {
                XCTFail("Expected ParseError, got \(error)")
                return
            }
            if case .missingRequiredField(let field) = parseError {
                XCTAssertEqual(field, "identifier")
            } else {
                XCTFail("Expected missingRequiredField(identifier), got \(parseError)")
            }
        }
    }

    // MARK: - Validation: Invalid Color Values

    func testValidateColorRedOutOfRange() {
        var theme = makeValidTheme()
        theme.colors.background = CodableColor(red: 1.5, green: 0, blue: 0, alpha: 1)
        XCTAssertThrowsError(try ThemeParser.validate(theme)) { error in
            guard let parseError = error as? ThemeParser.ParseError else {
                XCTFail("Expected ParseError")
                return
            }
            if case .invalidColorValue(let value) = parseError {
                XCTAssertTrue(value.contains("background"), "Error message should mention background, got: \(value)")
            } else {
                XCTFail("Expected invalidColorValue, got \(parseError)")
            }
        }
    }

    func testValidateColorNegativeValue() {
        var theme = makeValidTheme()
        theme.colors.text = CodableColor(red: -0.1, green: 0, blue: 0, alpha: 1)
        XCTAssertThrowsError(try ThemeParser.validate(theme)) { error in
            guard let parseError = error as? ThemeParser.ParseError else {
                XCTFail("Expected ParseError")
                return
            }
            if case .invalidColorValue(let value) = parseError {
                XCTAssertTrue(value.contains("text"), "Error message should mention text, got: \(value)")
            } else {
                XCTFail("Expected invalidColorValue, got \(parseError)")
            }
        }
    }

    func testValidateColorAlphaOutOfRange() {
        var theme = makeValidTheme()
        theme.colors.accent = CodableColor(red: 0, green: 0.5, blue: 1, alpha: 2.0)
        XCTAssertThrowsError(try ThemeParser.validate(theme)) { error in
            guard let parseError = error as? ThemeParser.ParseError else {
                XCTFail("Expected ParseError")
                return
            }
            if case .invalidColorValue = parseError {
                // Expected
            } else {
                XCTFail("Expected invalidColorValue, got \(parseError)")
            }
        }
    }

    func testValidateColorAtBoundaryValues() {
        var theme = makeValidTheme()
        // All values at exactly 0 or 1 should be valid
        theme.colors.background = CodableColor(red: 0, green: 0, blue: 0, alpha: 0)
        theme.colors.text = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
        XCTAssertNoThrow(try ThemeParser.validate(theme))
    }

    // MARK: - Validation: Invalid Font Size

    func testValidateZeroFontSizeThrows() {
        var theme = makeValidTheme()
        theme.fonts.body = CodableFont(family: "Helvetica", size: 0)
        XCTAssertThrowsError(try ThemeParser.validate(theme)) { error in
            guard let parseError = error as? ThemeParser.ParseError else {
                XCTFail("Expected ParseError")
                return
            }
            if case .invalidFontValue(let value) = parseError {
                XCTAssertTrue(value.contains("body"), "Error message should mention body font, got: \(value)")
            } else {
                XCTFail("Expected invalidFontValue, got \(parseError)")
            }
        }
    }

    func testValidateNegativeFontSizeThrows() {
        var theme = makeValidTheme()
        theme.fonts.code = CodableFont(family: "Courier", size: -5)
        XCTAssertThrowsError(try ThemeParser.validate(theme)) { error in
            guard let parseError = error as? ThemeParser.ParseError else {
                XCTFail("Expected ParseError")
                return
            }
            if case .invalidFontValue = parseError {
                // Expected
            } else {
                XCTFail("Expected invalidFontValue, got \(parseError)")
            }
        }
    }

    // MARK: - Validation: Invalid Tab Width

    func testValidateZeroTabWidthThrows() {
        var theme = makeValidTheme()
        theme.editor = EditorSettings(tabWidth: 0)
        XCTAssertThrowsError(try ThemeParser.validate(theme)) { error in
            guard let parseError = error as? ThemeParser.ParseError else {
                XCTFail("Expected ParseError")
                return
            }
            if case .invalidFontValue(let value) = parseError {
                XCTAssertTrue(value.contains("tab width"), "Error message should mention tab width, got: \(value)")
            } else {
                XCTFail("Expected invalidFontValue, got \(parseError)")
            }
        }
    }

    func testValidateNegativeTabWidthThrows() {
        var theme = makeValidTheme()
        theme.editor = EditorSettings(tabWidth: -1)
        XCTAssertThrowsError(try ThemeParser.validate(theme)) { error in
            guard let parseError = error as? ThemeParser.ParseError else {
                XCTFail("Expected ParseError")
                return
            }
            if case .invalidFontValue = parseError {
                // Expected
            } else {
                XCTFail("Expected invalidFontValue, got \(parseError)")
            }
        }
    }

    // MARK: - Serialize / Deserialize Round-Trip

    func testSerializeDeserializeRoundTrip() throws {
        let original = makeValidTheme()
        let data = try ThemeParser.serialize(original)
        let restored = try ThemeParser.parse(from: data)

        XCTAssertEqual(restored.name, original.name)
        XCTAssertEqual(restored.identifier, original.identifier)
        XCTAssertEqual(restored.colors, original.colors)
        XCTAssertEqual(restored.fonts, original.fonts)
        XCTAssertEqual(restored.spacing, original.spacing)
        XCTAssertEqual(restored.editor, original.editor)
    }

    func testSerializeToStringDeserializeRoundTrip() throws {
        let original = makeValidTheme()
        let string = try ThemeParser.serializeToString(original)
        let restored = try ThemeParser.parse(from: string)

        XCTAssertEqual(restored.name, original.name)
        XCTAssertEqual(restored.identifier, original.identifier)
        XCTAssertEqual(restored.colors, original.colors)
        XCTAssertEqual(restored.fonts, original.fonts)
    }

    func testSerializeProducesValidJSON() throws {
        let theme = makeValidTheme()
        let data = try ThemeParser.serialize(theme)
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(json is [String: Any], "Serialized theme should be a JSON object")
    }

    func testSerializeToStringProducesNonEmptyString() throws {
        let theme = makeValidTheme()
        let string = try ThemeParser.serializeToString(theme)
        XCTAssertFalse(string.isEmpty)
        XCTAssertTrue(string.contains("test-theme") || string.contains("test_theme"),
                       "Serialized string should contain the theme identifier")
    }

    func testSerializeBuiltInThemeRoundTrip() throws {
        for theme in BuiltInThemes.allThemes {
            let data = try ThemeParser.serialize(theme)
            let restored = try ThemeParser.parse(from: data)
            XCTAssertEqual(restored.name, theme.name, "Round-trip failed for \(theme.name)")
            XCTAssertEqual(restored.identifier, theme.identifier, "Round-trip failed for \(theme.name)")
            XCTAssertEqual(restored.colors, theme.colors, "Round-trip failed for \(theme.name)")
            XCTAssertEqual(restored.fonts, theme.fonts, "Round-trip failed for \(theme.name)")
        }
    }

    // MARK: - Parse from String

    func testParseFromString() throws {
        let original = makeValidTheme()
        let jsonString = try ThemeParser.serializeToString(original)
        let parsed = try ThemeParser.parse(from: jsonString)
        XCTAssertEqual(parsed.name, original.name)
        XCTAssertEqual(parsed.identifier, original.identifier)
    }

    func testParseFromInvalidJSONStringThrows() {
        XCTAssertThrowsError(try ThemeParser.parse(from: "not json at all")) { error in
            XCTAssertTrue(error is ThemeParser.ParseError, "Expected ParseError, got \(type(of: error))")
        }
    }

    func testParseFromEmptyStringThrows() {
        XCTAssertThrowsError(try ThemeParser.parse(from: "")) { error in
            XCTAssertTrue(error is ThemeParser.ParseError, "Expected ParseError, got \(type(of: error))")
        }
    }

    // MARK: - Parse from URL

    func testParseFromNonExistentURLThrows() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent_theme_\(UUID().uuidString).json")
        XCTAssertThrowsError(try ThemeParser.parse(from: url)) { error in
            guard let parseError = error as? ThemeParser.ParseError else {
                XCTFail("Expected ParseError")
                return
            }
            if case .fileNotFound = parseError {
                // Expected
            } else {
                XCTFail("Expected fileNotFound, got \(parseError)")
            }
        }
    }

    func testParseFromURLRoundTrip() throws {
        let original = makeValidTheme()
        let data = try ThemeParser.serialize(original)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_theme_\(UUID().uuidString).json")
        try data.write(to: tempURL)

        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parsed = try ThemeParser.parse(from: tempURL)
        XCTAssertEqual(parsed.name, original.name)
        XCTAssertEqual(parsed.identifier, original.identifier)
        XCTAssertEqual(parsed.colors, original.colors)
        XCTAssertEqual(parsed.fonts, original.fonts)
    }

    // MARK: - validateJSON

    func testValidateJSONWithValidTheme() throws {
        let theme = makeValidTheme()
        let data = try ThemeParser.serialize(theme)
        let errors = ThemeParser.validateJSON(data)
        XCTAssertTrue(errors.isEmpty, "Valid theme should produce no errors, got: \(errors)")
    }

    func testValidateJSONWithInvalidJSON() {
        let data = "not json".data(using: .utf8)!
        let errors = ThemeParser.validateJSON(data)
        XCTAssertFalse(errors.isEmpty, "Invalid JSON should produce errors")
    }

    func testValidateJSONWithEmptyName() throws {
        var theme = makeValidTheme()
        theme.name = ""
        // Encode directly (bypass ThemeParser.serialize which uses snake_case)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(theme)
        let errors = ThemeParser.validateJSON(data)
        XCTAssertFalse(errors.isEmpty, "Empty name should produce validation errors")
    }

    // MARK: - ParseError

    func testParseErrorDescriptions() {
        let errors: [ThemeParser.ParseError] = [
            .invalidJSON,
            .missingRequiredField("name"),
            .invalidColorValue("test"),
            .invalidFontValue("test"),
            .fileNotFound(URL(fileURLWithPath: "/test")),
            .decodeError(NSError(domain: "test", code: 0))
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }

    func testParseErrorInvalidJSONDescription() {
        let error = ThemeParser.ParseError.invalidJSON
        XCTAssertTrue(error.errorDescription!.contains("invalid JSON"),
                       "invalidJSON error should mention invalid JSON")
    }

    func testParseErrorMissingFieldDescription() {
        let error = ThemeParser.ParseError.missingRequiredField("name")
        XCTAssertTrue(error.errorDescription!.contains("name"),
                       "missingRequiredField error should mention the field name")
    }

    func testParseErrorInvalidColorDescription() {
        let error = ThemeParser.ParseError.invalidColorValue("background: bad")
        XCTAssertTrue(error.errorDescription!.contains("background: bad"),
                       "invalidColorValue error should contain the value")
    }

    func testParseErrorFileNotFoundDescription() {
        let url = URL(fileURLWithPath: "/some/path.json")
        let error = ThemeParser.ParseError.fileNotFound(url)
        XCTAssertTrue(error.errorDescription!.contains("/some/path.json"),
                       "fileNotFound error should contain the file path")
    }
}

// MARK: - ThemeTemplateGenerator Tests

final class ThemeTemplateGeneratorTests: XCTestCase {

    func testGenerateMinimalThemeHasCorrectName() {
        let theme = ThemeTemplateGenerator.generateMinimalTheme(name: "My Theme")
        XCTAssertEqual(theme.name, "My Theme")
    }

    func testGenerateMinimalThemeHasCorrectIdentifier() {
        let theme = ThemeTemplateGenerator.generateMinimalTheme(name: "My Theme")
        XCTAssertEqual(theme.identifier, "custom.my-theme")
    }

    func testGenerateMinimalThemeIdentifierWithSpaces() {
        let theme = ThemeTemplateGenerator.generateMinimalTheme(name: "Cool New Theme")
        XCTAssertEqual(theme.identifier, "custom.cool-new-theme")
    }

    func testGenerateMinimalThemeIsNotBuiltIn() {
        let theme = ThemeTemplateGenerator.generateMinimalTheme(name: "Test")
        XCTAssertFalse(theme.isBuiltIn)
    }

    func testGenerateMinimalThemePassesValidation() {
        let theme = ThemeTemplateGenerator.generateMinimalTheme(name: "Valid Theme")
        XCTAssertNoThrow(try ThemeParser.validate(theme))
    }

    func testGenerateMinimalThemeHasAllColors() {
        let theme = ThemeTemplateGenerator.generateMinimalTheme(name: "Test")
        let colors = theme.colors

        // Verify all 16 colors are set with valid values
        let allColors: [CodableColor] = [
            colors.background, colors.text, colors.secondaryText,
            colors.accent, colors.link, colors.codeBackground,
            colors.codeText, colors.heading, colors.quoteBorder,
            colors.quoteText, colors.listMarker, colors.syntaxHidden,
            colors.selection, colors.cursor, colors.sidebarBackground,
            colors.sidebarText
        ]

        for color in allColors {
            XCTAssertTrue(color.red >= 0 && color.red <= 1)
            XCTAssertTrue(color.green >= 0 && color.green <= 1)
            XCTAssertTrue(color.blue >= 0 && color.blue <= 1)
            XCTAssertTrue(color.alpha >= 0 && color.alpha <= 1)
        }
    }

    func testGenerateMinimalThemeHasFonts() {
        let theme = ThemeTemplateGenerator.generateMinimalTheme(name: "Test")
        XCTAssertFalse(theme.fonts.body.family.isEmpty)
        XCTAssertFalse(theme.fonts.code.family.isEmpty)
        XCTAssertGreaterThan(theme.fonts.body.size, 0)
        XCTAssertGreaterThan(theme.fonts.code.size, 0)
    }

    func testGenerateMinimalThemeSerializesSuccessfully() throws {
        let theme = ThemeTemplateGenerator.generateMinimalTheme(name: "Serializable")
        XCTAssertNoThrow(try ThemeParser.serialize(theme))
    }

    func testGenerateMinimalThemeRoundTripsThroughParser() throws {
        let original = ThemeTemplateGenerator.generateMinimalTheme(name: "RoundTrip")
        let data = try ThemeParser.serialize(original)
        let restored = try ThemeParser.parse(from: data)
        XCTAssertEqual(restored.name, original.name)
        XCTAssertEqual(restored.identifier, original.identifier)
        XCTAssertEqual(restored.colors, original.colors)
        XCTAssertEqual(restored.fonts, original.fonts)
    }

    // MARK: - generateThemeTemplate

    func testGenerateThemeTemplateIsNonEmpty() {
        let template = ThemeTemplateGenerator.generateThemeTemplate()
        XCTAssertFalse(template.isEmpty)
    }

    func testGenerateThemeTemplateIsValidJSON() {
        let template = ThemeTemplateGenerator.generateThemeTemplate()
        let data = template.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testGenerateThemeTemplateContainsRequiredKeys() {
        let template = ThemeTemplateGenerator.generateThemeTemplate()
        XCTAssertTrue(template.contains("\"name\""), "Template should contain name key")
        XCTAssertTrue(template.contains("\"identifier\""), "Template should contain identifier key")
        XCTAssertTrue(template.contains("\"colors\""), "Template should contain colors key")
        XCTAssertTrue(template.contains("\"fonts\""), "Template should contain fonts key")
        XCTAssertTrue(template.contains("\"spacing\""), "Template should contain spacing key")
        XCTAssertTrue(template.contains("\"editor\""), "Template should contain editor key")
    }

    func testGenerateThemeTemplateContainsAllColorKeys() {
        let template = ThemeTemplateGenerator.generateThemeTemplate()
        let expectedColorKeys = [
            "background", "text", "secondary_text", "accent", "link",
            "code_background", "code_text", "heading", "quote_border",
            "quote_text", "list_marker", "syntax_hidden", "selection",
            "cursor", "sidebar_background", "sidebar_text"
        ]
        for key in expectedColorKeys {
            XCTAssertTrue(template.contains("\"\(key)\""), "Template should contain color key: \(key)")
        }
    }

    func testGenerateThemeTemplateContainsAllFontKeys() {
        let template = ThemeTemplateGenerator.generateThemeTemplate()
        XCTAssertTrue(template.contains("\"body\""), "Template should contain body font")
        XCTAssertTrue(template.contains("\"heading\""), "Template should contain heading font")
        XCTAssertTrue(template.contains("\"code\""), "Template should contain code font")
        XCTAssertTrue(template.contains("\"quote\""), "Template should contain quote font")
    }

    func testGenerateThemeTemplateContainsEditorSettings() {
        let template = ThemeTemplateGenerator.generateThemeTemplate()
        let expectedEditorKeys = [
            "show_line_numbers", "show_invisibles", "wrap_lines",
            "tab_width", "use_spaces_for_tabs", "focus_mode", "typewriter_mode"
        ]
        for key in expectedEditorKeys {
            XCTAssertTrue(template.contains("\"\(key)\""), "Template should contain editor key: \(key)")
        }
    }

    func testGenerateThemeTemplateParsesWithSnakeCaseDecoder() throws {
        let template = ThemeTemplateGenerator.generateThemeTemplate()
        let data = template.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let theme = try decoder.decode(Theme.self, from: data)
        XCTAssertEqual(theme.name, "My Custom Theme")
        XCTAssertEqual(theme.identifier, "custom.my-theme")
        XCTAssertFalse(theme.isBuiltIn)
    }
}

// MARK: - NSEdgeInsets Codable Tests

final class NSEdgeInsetsCodableTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let original = NSEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NSEdgeInsets.self, from: data)
        XCTAssertEqual(decoded.top, original.top)
        XCTAssertEqual(decoded.left, original.left)
        XCTAssertEqual(decoded.bottom, original.bottom)
        XCTAssertEqual(decoded.right, original.right)
    }

    func testCodableZeroInsets() throws {
        let original = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NSEdgeInsets.self, from: data)
        XCTAssertEqual(decoded.top, 0)
        XCTAssertEqual(decoded.left, 0)
        XCTAssertEqual(decoded.bottom, 0)
        XCTAssertEqual(decoded.right, 0)
    }

    func testEncodedJSONContainsExpectedKeys() throws {
        let insets = NSEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
        let data = try JSONEncoder().encode(insets)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["top"])
        XCTAssertNotNil(json["left"])
        XCTAssertNotNil(json["bottom"])
        XCTAssertNotNil(json["right"])
    }
}
