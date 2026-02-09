import Cocoa

// MARK: - Rich Content Attachment

/// Custom NSTextAttachment for rendering rich content (Mermaid diagrams, LaTeX math)
/// as inline images in the text view.
public final class RichContentAttachment: NSTextAttachment {

    public enum ContentType {
        case mermaid(definition: String)
        case math(latex: String, displayMode: Bool)
        case image(url: URL)
    }

    public let contentType: ContentType
    private var renderedImage: NSImage?

    public init(contentType: ContentType) {
        self.contentType = contentType
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) {
        self.contentType = .math(latex: "", displayMode: false)
        super.init(coder: coder)
    }

    // MARK: - Rendering

    public func setRenderedImage(_ image: NSImage) {
        self.renderedImage = image
        self.image = image
    }

    public override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        guard let image = renderedImage ?? self.image else {
            // Placeholder size
            switch contentType {
            case .mermaid:
                return CGRect(x: 0, y: 0, width: 300, height: 200)
            case .math(_, let displayMode):
                return displayMode
                    ? CGRect(x: 0, y: -4, width: lineFrag.width, height: 40)
                    : CGRect(x: 0, y: -4, width: 60, height: 20)
            case .image:
                return CGRect(x: 0, y: 0, width: 200, height: 150)
            }
        }

        let maxWidth = lineFrag.width
        let imageSize = image.size

        if imageSize.width > maxWidth {
            let scale = maxWidth / imageSize.width
            return CGRect(x: 0, y: 0, width: maxWidth, height: imageSize.height * scale)
        }

        return CGRect(origin: .zero, size: imageSize)
    }
}
