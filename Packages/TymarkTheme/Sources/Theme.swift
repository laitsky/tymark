import Foundation
import AppKit

// MARK: - Theme

public struct Theme: Identifiable, Equatable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var identifier: String
    public var isBuiltIn: Bool
    public var colors: ThemeColors
    public var fonts: ThemeFonts
    public var spacing: ThemeSpacing
    public var editor: EditorSettings

    public init(
        id: UUID = UUID(),
        name: String,
        identifier: String,
        isBuiltIn: Bool = false,
        colors: ThemeColors,
        fonts: ThemeFonts,
        spacing: ThemeSpacing = ThemeSpacing(),
        editor: EditorSettings = EditorSettings()
    ) {
        self.id = id
        self.name = name
        self.identifier = identifier
        self.isBuiltIn = isBuiltIn
        self.colors = colors
        self.fonts = fonts
        self.spacing = spacing
        self.editor = editor
    }

    public static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.identifier == rhs.identifier &&
        lhs.name == rhs.name &&
        lhs.colors == rhs.colors &&
        lhs.fonts == rhs.fonts &&
        lhs.spacing == rhs.spacing &&
        lhs.editor == rhs.editor
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(name)
    }
}

// MARK: - Theme Colors

public struct ThemeColors: Codable, Equatable {
    public var background: CodableColor
    public var text: CodableColor
    public var secondaryText: CodableColor
    public var accent: CodableColor
    public var link: CodableColor
    public var codeBackground: CodableColor
    public var codeText: CodableColor
    public var heading: CodableColor
    public var quoteBorder: CodableColor
    public var quoteText: CodableColor
    public var listMarker: CodableColor
    public var syntaxHidden: CodableColor
    public var selection: CodableColor
    public var cursor: CodableColor
    public var sidebarBackground: CodableColor
    public var sidebarText: CodableColor

    public init(
        background: CodableColor,
        text: CodableColor,
        secondaryText: CodableColor,
        accent: CodableColor,
        link: CodableColor,
        codeBackground: CodableColor,
        codeText: CodableColor,
        heading: CodableColor,
        quoteBorder: CodableColor,
        quoteText: CodableColor,
        listMarker: CodableColor,
        syntaxHidden: CodableColor,
        selection: CodableColor,
        cursor: CodableColor,
        sidebarBackground: CodableColor,
        sidebarText: CodableColor
    ) {
        self.background = background
        self.text = text
        self.secondaryText = secondaryText
        self.accent = accent
        self.link = link
        self.codeBackground = codeBackground
        self.codeText = codeText
        self.heading = heading
        self.quoteBorder = quoteBorder
        self.quoteText = quoteText
        self.listMarker = listMarker
        self.syntaxHidden = syntaxHidden
        self.selection = selection
        self.cursor = cursor
        self.sidebarBackground = sidebarBackground
        self.sidebarText = sidebarText
    }
}

// MARK: - Theme Fonts

public struct ThemeFonts: Codable, Equatable {
    public var body: CodableFont
    public var heading: CodableFont
    public var code: CodableFont
    public var quote: CodableFont

    public init(
        body: CodableFont,
        heading: CodableFont? = nil,
        code: CodableFont,
        quote: CodableFont? = nil
    ) {
        self.body = body
        self.heading = heading ?? body.withWeight(.bold)
        self.code = code
        self.quote = quote ?? body.withStyle(.italicFontMask)
    }
}

// MARK: - Theme Spacing

public struct ThemeSpacing: Codable {
    public var paragraphSpacing: CGFloat
    public var lineHeight: CGFloat
    public var headingSpacingTop: CGFloat
    public var headingSpacingBottom: CGFloat
    public var listIndentation: CGFloat
    public var blockquoteIndentation: CGFloat
    public var codeBlockPadding: CGFloat
    public var pageMargins: NSEdgeInsets

    public init(
        paragraphSpacing: CGFloat = 8,
        lineHeight: CGFloat = 1.6,
        headingSpacingTop: CGFloat = 24,
        headingSpacingBottom: CGFloat = 12,
        listIndentation: CGFloat = 24,
        blockquoteIndentation: CGFloat = 16,
        codeBlockPadding: CGFloat = 12,
        pageMargins: NSEdgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    ) {
        self.paragraphSpacing = paragraphSpacing
        self.lineHeight = lineHeight
        self.headingSpacingTop = headingSpacingTop
        self.headingSpacingBottom = headingSpacingBottom
        self.listIndentation = listIndentation
        self.blockquoteIndentation = blockquoteIndentation
        self.codeBlockPadding = codeBlockPadding
        self.pageMargins = pageMargins
    }
}

extension ThemeSpacing: Equatable {
    public static func == (lhs: ThemeSpacing, rhs: ThemeSpacing) -> Bool {
        return lhs.paragraphSpacing == rhs.paragraphSpacing &&
               lhs.lineHeight == rhs.lineHeight &&
               lhs.headingSpacingTop == rhs.headingSpacingTop &&
               lhs.headingSpacingBottom == rhs.headingSpacingBottom &&
               lhs.listIndentation == rhs.listIndentation &&
               lhs.blockquoteIndentation == rhs.blockquoteIndentation &&
               lhs.codeBlockPadding == rhs.codeBlockPadding &&
               lhs.pageMargins.top == rhs.pageMargins.top &&
               lhs.pageMargins.left == rhs.pageMargins.left &&
               lhs.pageMargins.bottom == rhs.pageMargins.bottom &&
               lhs.pageMargins.right == rhs.pageMargins.right
    }
}

// MARK: - Editor Settings

public struct EditorSettings: Codable, Equatable {
    public var showLineNumbers: Bool
    public var showInvisibles: Bool
    public var wrapLines: Bool
    public var tabWidth: Int
    public var useSpacesForTabs: Bool
    public var focusMode: Bool
    public var typewriterMode: Bool

    public init(
        showLineNumbers: Bool = false,
        showInvisibles: Bool = false,
        wrapLines: Bool = true,
        tabWidth: Int = 4,
        useSpacesForTabs: Bool = true,
        focusMode: Bool = false,
        typewriterMode: Bool = false
    ) {
        self.showLineNumbers = showLineNumbers
        self.showInvisibles = showInvisibles
        self.wrapLines = wrapLines
        self.tabWidth = tabWidth
        self.useSpacesForTabs = useSpacesForTabs
        self.focusMode = focusMode
        self.typewriterMode = typewriterMode
    }
}

// MARK: - Codable Color

public struct CodableColor: Codable, Equatable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(color: NSColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1.0

        if let sRGBColor = color.usingColorSpace(.sRGB) {
            sRGBColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        } else {
            // Fallback: try genericRGB or default to opaque black
            if let rgbColor = color.usingColorSpace(.genericRGB) {
                rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            }
        }

        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }

    public var nsColor: NSColor {
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public func withAlphaComponent(_ alpha: CGFloat) -> CodableColor {
        return CodableColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - Codable Font

public struct CodableFont: Codable, Equatable {
    public var family: String
    public var size: CGFloat
    public var weight: String
    public var isItalic: Bool

    public init(family: String, size: CGFloat, weight: String = "Regular", isItalic: Bool = false) {
        self.family = family
        self.size = size
        self.weight = weight
        self.isItalic = isItalic
    }

    public var nsFont: NSFont {
        let traits: NSFontTraitMask = isItalic ? .italicFontMask : []
        let weightMap: [String: Int] = [
            "UltraLight": 1,
            "Thin": 2,
            "Light": 3,
            "Regular": 5,
            "Medium": 6,
            "Semibold": 8,
            "Bold": 9,
            "Heavy": 11,
            "Black": 12
        ]

        let weightValue = weightMap[weight] ?? 5

        if let font = NSFontManager.shared.font(withFamily: family, traits: traits, weight: weightValue, size: size) {
            return font
        }

        // Fallback to system font
        return NSFont.systemFont(ofSize: size, weight: convertWeight(weight))
    }

    private func convertWeight(_ weight: String) -> NSFont.Weight {
        switch weight {
        case "UltraLight": return .ultraLight
        case "Thin": return .thin
        case "Light": return .light
        case "Medium": return .medium
        case "Semibold": return .semibold
        case "Bold": return .bold
        case "Heavy": return .heavy
        case "Black": return .black
        default: return .regular
        }
    }

    public func withWeight(_ weight: NSFont.Weight) -> CodableFont {
        let weightString: String
        switch weight {
        case .ultraLight: weightString = "UltraLight"
        case .thin: weightString = "Thin"
        case .light: weightString = "Light"
        case .medium: weightString = "Medium"
        case .semibold: weightString = "Semibold"
        case .bold: weightString = "Bold"
        case .heavy: weightString = "Heavy"
        case .black: weightString = "Black"
        default: weightString = "Regular"
        }
        return CodableFont(family: family, size: size, weight: weightString, isItalic: isItalic)
    }

    public func withStyle(_ style: NSFontTraitMask) -> CodableFont {
        return CodableFont(family: family, size: size, weight: weight, isItalic: style.contains(.italicFontMask))
    }
}

// MARK: - NSEdgeInsets Codable

extension NSEdgeInsets: Codable {
    enum CodingKeys: String, CodingKey {
        case top, left, bottom, right
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            top: try container.decode(CGFloat.self, forKey: .top),
            left: try container.decode(CGFloat.self, forKey: .left),
            bottom: try container.decode(CGFloat.self, forKey: .bottom),
            right: try container.decode(CGFloat.self, forKey: .right)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(top, forKey: .top)
        try container.encode(left, forKey: .left)
        try container.encode(bottom, forKey: .bottom)
        try container.encode(right, forKey: .right)
    }
}
