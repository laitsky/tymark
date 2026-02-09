import Foundation
import TymarkParser
import TymarkTheme

@main
struct TymarkSmokeCheck {
    static func main() {
        let markdown = """
        ---
        title: Smoke Check
        author: Tymark
        ---

        # Heading 1

        Paragraph with **bold**, *italic*, and `inline code`.

        > Blockquote line 1
        > Blockquote line 2

        ```swift
        print("hello")
        ```
        """

        let parser = MarkdownParser()
        let document = parser.parse(markdown)

        // Ensure rendering preserves the original backing string to avoid edit/render feedback loops.
        let theme = BuiltInThemes.light
        let context = RenderingContext(
            isSourceMode: false,
            baseFont: theme.fonts.body.nsFont,
            baseColor: theme.colors.text.nsColor,
            codeFont: theme.fonts.code.nsFont,
            linkColor: theme.colors.link.nsColor,
            syntaxHiddenColor: theme.colors.syntaxHidden.nsColor,
            codeBackgroundColor: theme.colors.codeBackground.nsColor,
            blockquoteColor: theme.colors.secondaryText.nsColor
        )

        let renderer = ASTToAttributedString(context: context)
        let attributed = renderer.convert(document)

        guard attributed.string == markdown else {
            fputs("SmokeCheck failed: renderer changed the backing string.\n", stderr)
            exit(1)
        }

        print("SmokeCheck OK")
    }
}

