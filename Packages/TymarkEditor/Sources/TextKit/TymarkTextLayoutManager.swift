import Cocoa
import TymarkParser

// MARK: - Custom Text Layout Manager

public final class TymarkTextLayoutManager: NSLayoutManager {

    // MARK: - Properties

    private var layoutFragments: [NSTextLayoutFragment] = []
    private var currentDocument: TymarkDocument?

    // MARK: - Initialization

    public override init() {
        super.init()
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Configure layout manager settings
        self.allowsNonContiguousLayout = false
        self.showsInvisibleCharacters = false
        self.showsControlCharacters = false
    }

    // MARK: - Layout Overrides

    public override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        // Custom drawing for inline rendered elements
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)

        // Draw any custom decorations (syntax highlighting, etc.)
        drawCustomDecorations(forGlyphRange: glyphsToShow, at: origin)
    }

    // MARK: - Custom Drawing

    private func drawCustomDecorations(forGlyphRange range: NSRange, at origin: NSPoint) {
        guard let textStorage = self.textStorage,
              currentDocument != nil else { return }

        // Enumerate through the range and draw custom decorations
        textStorage.enumerateAttributes(in: range) { attributes, attrRange, _ in
            // Check for special node types
            if let nodeType = attributes[TymarkRenderingAttribute.nodeTypeKey] as? TymarkNodeType {
                switch nodeType {
                case .codeBlock:
                    self.drawCodeBlockBackground(for: attrRange, at: origin, in: textStorage)
                case .blockquote:
                    self.drawBlockQuoteIndicator(for: attrRange, at: origin, in: textStorage)
                case .thematicBreak:
                    self.drawHorizontalRule(for: attrRange, at: origin, in: textStorage)
                default:
                    break
                }
            }
        }
    }

    private func drawCodeBlockBackground(for range: NSRange, at origin: NSPoint, in textStorage: NSTextStorage) {
        guard let textContainer = self.textContainers.first else { return }

        let rect = self.boundingRect(forGlyphRange: range, in: textContainer)
        let adjustedRect = rect.offsetBy(dx: origin.x, dy: origin.y)

        // Draw code block background
        let path = NSBezierPath(roundedRect: adjustedRect, xRadius: 4, yRadius: 4)
        NSColor.textBackgroundColor.withAlphaComponent(0.5).setFill()
        path.fill()
    }

    private func drawBlockQuoteIndicator(for range: NSRange, at origin: NSPoint, in textStorage: NSTextStorage) {
        guard let textContainer = self.textContainers.first else { return }

        let rect = self.boundingRect(forGlyphRange: range, in: textContainer)
        let adjustedRect = rect.offsetBy(dx: origin.x, dy: origin.y)

        // Draw blockquote left border
        let lineRect = NSRect(
            x: adjustedRect.minX,
            y: adjustedRect.minY,
            width: 3,
            height: adjustedRect.height
        )

        let path = NSBezierPath(rect: lineRect)
        NSColor.separatorColor.setFill()
        path.fill()
    }

    private func drawHorizontalRule(for range: NSRange, at origin: NSPoint, in textStorage: NSTextStorage) {
        guard let textContainer = self.textContainers.first else { return }

        let rect = self.boundingRect(forGlyphRange: range, in: textContainer)
        let adjustedRect = rect.offsetBy(dx: origin.x, dy: origin.y)

        // Draw horizontal line
        let lineRect = NSRect(
            x: adjustedRect.minX,
            y: adjustedRect.midY - 0.5,
            width: adjustedRect.width,
            height: 1
        )

        let path = NSBezierPath(rect: lineRect)
        NSColor.separatorColor.setFill()
        path.fill()
    }

    // MARK: - Public API

    public func setDocument(_ document: TymarkDocument) {
        self.currentDocument = document
        // Invalidate layout to trigger redraw
        self.invalidateLayout(forCharacterRange: NSRange(location: 0, length: (self.textStorage?.length ?? 0)),
                              actualCharacterRange: nil)
    }

    // MARK: - Layout Fragment Management

    public override func layoutManagerOwnsFirstResponder(in window: NSWindow) -> Bool {
        // Let the text view handle first responder
        return false
    }

}

// MARK: - Layout Fragment

public final class TymarkTextLayoutFragment: NSTextLayoutFragment {

    // MARK: - Properties

    private var nodeType: TymarkNodeType?

    // MARK: - Initialization

    public override init(textElement: NSTextElement, range rangeInElement: NSTextRange?) {
        super.init(textElement: textElement, range: rangeInElement)
        extractNodeType(from: textElement)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Setup

    private func extractNodeType(from textElement: NSTextElement) {
        // Extract the node type from paragraph attributes
        guard let paragraph = textElement as? NSTextParagraph,
              paragraph.attributedString.length > 0 else { return }
        let attributes = paragraph.attributedString.attributes(at: 0, effectiveRange: nil)
        self.nodeType = attributes[TymarkRenderingAttribute.nodeTypeKey] as? TymarkNodeType
    }

    // MARK: - Drawing

    public override func draw(at point: NSPoint, in context: CGContext) {
        // Custom drawing based on node type
        if let nodeType = nodeType {
            switch nodeType {
            case .heading:
                drawHeadingDecoration(at: point, in: context)
            case .codeBlock:
                drawCodeBlockDecoration(at: point, in: context)
            default:
                break
            }
        }

        super.draw(at: point, in: context)
    }

    private func drawHeadingDecoration(at point: NSPoint, in context: CGContext) {
        // Draw heading underline or other decorations
        let lineRect = CGRect(
            x: point.x,
            y: point.y + self.layoutFragmentFrame.height - 2,
            width: self.layoutFragmentFrame.width * 0.3,
            height: 1
        )

        context.setFillColor(NSColor.separatorColor.cgColor)
        context.fill(lineRect)
    }

    private func drawCodeBlockDecoration(at point: NSPoint, in context: CGContext) {
        // Draw code block background
        let backgroundRect = self.layoutFragmentFrame.offsetBy(dx: point.x, dy: point.y)

        context.setFillColor(NSColor.textBackgroundColor.withAlphaComponent(0.5).cgColor)
        context.fill(backgroundRect)
    }
}
