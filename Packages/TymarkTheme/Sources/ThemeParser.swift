import Foundation

// MARK: - Theme Parser

public final class ThemeParser {

    public enum ParseError: Error, LocalizedError {
        case invalidJSON
        case missingRequiredField(String)
        case invalidColorValue(String)
        case invalidFontValue(String)
        case fileNotFound(URL)
        case decodeError(Error)

        public var errorDescription: String? {
            switch self {
            case .invalidJSON:
                return "The theme file contains invalid JSON."
            case .missingRequiredField(let field):
                return "Missing required field: \(field)"
            case .invalidColorValue(let value):
                return "Invalid color value: \(value)"
            case .invalidFontValue(let value):
                return "Invalid font value: \(value)"
            case .fileNotFound(let url):
                return "Theme file not found: \(url.path)"
            case .decodeError(let error):
                return "Failed to decode theme: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Public API

    public static func parse(from url: URL) throws -> Theme {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParseError.fileNotFound(url)
        }

        do {
            let data = try Data(contentsOf: url)
            return try parse(from: data)
        } catch let error as ParseError {
            throw error
        } catch {
            throw ParseError.decodeError(error)
        }
    }

    public static func parse(from data: Data) throws -> Theme {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let theme = try decoder.decode(Theme.self, from: data)
            try validate(theme)
            return theme
        } catch let error as ParseError {
            throw error
        } catch {
            throw ParseError.decodeError(error)
        }
    }

    public static func parse(from string: String) throws -> Theme {
        guard let data = string.data(using: .utf8) else {
            throw ParseError.invalidJSON
        }
        return try parse(from: data)
    }

    public static func serialize(_ theme: Theme) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(theme)
    }

    public static func serializeToString(_ theme: Theme) throws -> String {
        let data = try serialize(theme)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ParseError.invalidJSON
        }
        return string
    }

    // MARK: - Validation

    public static func validate(_ theme: Theme) throws {
        // Check required fields
        if theme.name.isEmpty {
            throw ParseError.missingRequiredField("name")
        }

        if theme.identifier.isEmpty {
            throw ParseError.missingRequiredField("identifier")
        }

        // Validate all color components are in [0, 1]
        let allColors: [(String, CodableColor)] = [
            ("background", theme.colors.background),
            ("text", theme.colors.text),
            ("secondaryText", theme.colors.secondaryText),
            ("accent", theme.colors.accent),
            ("link", theme.colors.link),
            ("codeBackground", theme.colors.codeBackground),
            ("codeText", theme.colors.codeText),
            ("heading", theme.colors.heading),
            ("quoteBorder", theme.colors.quoteBorder),
            ("quoteText", theme.colors.quoteText),
            ("listMarker", theme.colors.listMarker),
            ("syntaxHidden", theme.colors.syntaxHidden),
            ("selection", theme.colors.selection),
            ("cursor", theme.colors.cursor),
            ("sidebarBackground", theme.colors.sidebarBackground),
            ("sidebarText", theme.colors.sidebarText),
        ]

        for (name, color) in allColors {
            let validRange: ClosedRange<CGFloat> = 0...1
            if !validRange.contains(color.red) || !validRange.contains(color.green) ||
               !validRange.contains(color.blue) || !validRange.contains(color.alpha) {
                throw ParseError.invalidColorValue("\(name): RGBA(\(color.red), \(color.green), \(color.blue), \(color.alpha))")
            }
        }

        // Validate all font sizes are positive
        let allFontSizes: [(String, CGFloat)] = [
            ("body", theme.fonts.body.size),
            ("heading", theme.fonts.heading.size),
            ("code", theme.fonts.code.size),
            ("quote", theme.fonts.quote.size),
        ]

        for (name, size) in allFontSizes {
            if size <= 0 {
                throw ParseError.invalidFontValue("\(name) font size: \(size)")
            }
        }

        // Validate editor settings
        if theme.editor.tabWidth <= 0 {
            throw ParseError.invalidFontValue("tab width must be positive: \(theme.editor.tabWidth)")
        }
    }

    public static func validateJSON(_ data: Data) -> [String] {
        var errors: [String] = []

        do {
            let _ = try parse(from: data)
        } catch let error as ParseError {
            errors.append(error.localizedDescription)
        } catch {
            errors.append("Unknown error: \(error.localizedDescription)")
        }

        return errors
    }

    // MARK: - Legacy Format Support

    public static func migrateTheme(from url: URL) throws -> Theme {
        // Support for migrating from old theme formats
        let data = try Data(contentsOf: url)

        // Try to detect format and convert
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return try migrateFromLegacyFormat(json)
        }

        throw ParseError.invalidJSON
    }

    private static func migrateFromLegacyFormat(_ json: [String: Any]) throws -> Theme {
        // Extract values with fallbacks
        let name = json["name"] as? String ?? "Migrated Theme"
        let identifier = json["identifier"] as? String ?? "custom.migrated"

        // Convert colors
        var colors = BuiltInThemes.light.colors

        if let colorDict = json["colors"] as? [String: Any] {
            colors.background = parseColor(from: colorDict["background"]) ?? colors.background
            colors.text = parseColor(from: colorDict["text"]) ?? colors.text
            colors.link = parseColor(from: colorDict["link"]) ?? colors.link
        }

        // Convert fonts
        var fonts = BuiltInThemes.light.fonts

        if let fontDict = json["fonts"] as? [String: Any] {
            if let bodyDict = fontDict["body"] as? [String: Any] {
                fonts.body = CodableFont(
                    family: bodyDict["family"] as? String ?? "SF Pro",
                    size: bodyDict["size"] as? CGFloat ?? 14
                )
            }
        }

        return Theme(
            name: name,
            identifier: identifier,
            isBuiltIn: false,
            colors: colors,
            fonts: fonts
        )
    }

    private static func parseColor(from value: Any?) -> CodableColor? {
        if let hexString = value as? String {
            return CodableColor.fromHex(hexString)
        }
        if let rgba = value as? [String: CGFloat] {
            return CodableColor(
                red: rgba["r"] ?? 0,
                green: rgba["g"] ?? 0,
                blue: rgba["b"] ?? 0,
                alpha: rgba["a"] ?? 1
            )
        }
        return nil
    }
}

// MARK: - Color Hex Extensions

extension CodableColor {
    public static func fromHex(_ hex: String) -> CodableColor? {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1

        if hexString.count == 6 {
            let scanner = Scanner(string: hexString)
            var hexNumber: UInt64 = 0
            guard scanner.scanHexInt64(&hexNumber) else { return nil }

            r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
            g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
            b = CGFloat(hexNumber & 0x0000FF) / 255.0
        } else if hexString.count == 8 {
            let scanner = Scanner(string: hexString)
            var hexNumber: UInt64 = 0
            guard scanner.scanHexInt64(&hexNumber) else { return nil }

            r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255.0
            g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(hexNumber & 0x000000FF) / 255.0
        } else {
            return nil
        }

        return CodableColor(red: r, green: g, blue: b, alpha: a)
    }

    public var hexString: String {
        let r = Int(max(0, min(255, red * 255)))
        let g = Int(max(0, min(255, green * 255)))
        let b = Int(max(0, min(255, blue * 255)))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    public var hexStringWithAlpha: String {
        let r = Int(max(0, min(255, red * 255)))
        let g = Int(max(0, min(255, green * 255)))
        let b = Int(max(0, min(255, blue * 255)))
        let a = Int(max(0, min(255, alpha * 255)))
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}

// MARK: - Theme Template Generator

public struct ThemeTemplateGenerator {

    public static func generateMinimalTheme(name: String) -> Theme {
        return Theme(
            name: name,
            identifier: "custom.\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            isBuiltIn: false,
            colors: ThemeColors(
                background: CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
                text: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
                secondaryText: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
                accent: CodableColor(red: 0, green: 0.48, blue: 1, alpha: 1),
                link: CodableColor(red: 0, green: 0.48, blue: 1, alpha: 1),
                codeBackground: CodableColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.2),
                codeText: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
                heading: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
                quoteBorder: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
                quoteText: CodableColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1),
                listMarker: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
                syntaxHidden: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.5),
                selection: CodableColor(red: 0, green: 0.48, blue: 1, alpha: 0.3),
                cursor: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
                sidebarBackground: CodableColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
                sidebarText: CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
            ),
            fonts: ThemeFonts(
                body: CodableFont(family: "SF Pro", size: 14),
                code: CodableFont(family: "SF Mono", size: 13)
            )
        )
    }

    public static func generateThemeTemplate() -> String {
        return """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "My Custom Theme",
          "identifier": "custom.my-theme",
          "is_built_in": false,
          "colors": {
            "background": { "red": 1.0, "green": 1.0, "blue": 1.0, "alpha": 1.0 },
            "text": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
            "secondary_text": { "red": 0.5, "green": 0.5, "blue": 0.5, "alpha": 1.0 },
            "accent": { "red": 0.0, "green": 0.48, "blue": 1.0, "alpha": 1.0 },
            "link": { "red": 0.0, "green": 0.48, "blue": 1.0, "alpha": 1.0 },
            "code_background": { "red": 0.95, "green": 0.95, "blue": 0.95, "alpha": 1.0 },
            "code_text": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
            "heading": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
            "quote_border": { "red": 0.8, "green": 0.8, "blue": 0.8, "alpha": 1.0 },
            "quote_text": { "red": 0.4, "green": 0.4, "blue": 0.4, "alpha": 1.0 },
            "list_marker": { "red": 0.5, "green": 0.5, "blue": 0.5, "alpha": 1.0 },
            "syntax_hidden": { "red": 0.8, "green": 0.8, "blue": 0.8, "alpha": 0.3 },
            "selection": { "red": 0.0, "green": 0.48, "blue": 1.0, "alpha": 0.3 },
            "cursor": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
            "sidebar_background": { "red": 0.95, "green": 0.95, "blue": 0.95, "alpha": 1.0 },
            "sidebar_text": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 }
          },
          "fonts": {
            "body": { "family": "SF Pro", "size": 14, "weight": "Regular", "is_italic": false },
            "heading": { "family": "SF Pro", "size": 16, "weight": "Bold", "is_italic": false },
            "code": { "family": "SF Mono", "size": 13, "weight": "Regular", "is_italic": false },
            "quote": { "family": "SF Pro", "size": 14, "weight": "Regular", "is_italic": true }
          },
          "spacing": {
            "paragraph_spacing": 8,
            "line_height": 1.6,
            "heading_spacing_top": 24,
            "heading_spacing_bottom": 12,
            "list_indentation": 24,
            "blockquote_indentation": 16,
            "code_block_padding": 12,
            "page_margins": {
              "top": 20,
              "left": 20,
              "bottom": 20,
              "right": 20
            }
          },
          "editor": {
            "show_line_numbers": false,
            "show_invisibles": false,
            "wrap_lines": true,
            "tab_width": 4,
            "use_spaces_for_tabs": true,
            "focus_mode": false,
            "typewriter_mode": false
          }
        }
        """
    }
}
