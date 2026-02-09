import SwiftUI
import TymarkParser
import TymarkTheme

// MARK: - Tymark Editor SwiftUI View

public struct TymarkEditorView: NSViewRepresentable {

    // MARK: - Properties

    @Binding public var text: String
    @Binding public var selection: NSRange
    @ObservedObject public var viewModel: EditorViewModel
    public var keybindingHandler: KeybindingHandler?
    public var vimModeHandler: VimModeHandler?
    /// Callback invoked when the text view is created, providing a TextManipulating reference.
    public var onTextManipulatorReady: ((any TextManipulating) -> Void)?
    /// The URL of the current document, used for image paste.
    public var documentURL: URL?

    // MARK: - Initialization

    public init(
        text: Binding<String>,
        selection: Binding<NSRange> = .constant(NSRange(location: 0, length: 0)),
        viewModel: EditorViewModel,
        keybindingHandler: KeybindingHandler? = nil,
        vimModeHandler: VimModeHandler? = nil,
        onTextManipulatorReady: ((any TextManipulating) -> Void)? = nil,
        documentURL: URL? = nil
    ) {
        self._text = text
        self._selection = selection
        self.viewModel = viewModel
        self.keybindingHandler = keybindingHandler
        self.vimModeHandler = vimModeHandler
        self.onTextManipulatorReady = onTextManipulatorReady
        self.documentURL = documentURL
    }

    // MARK: - NSViewRepresentable

    public func makeNSView(context: Context) -> NSScrollView {
        // Create the scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // Create the text view
        let textView = TymarkTextView(
            frame: scrollView.bounds,
            theme: viewModel.theme
        )
        textView.minSize = NSSize(width: 0, height: scrollView.bounds.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // Set the text
        textView.setMarkdown(text)
        textView.keybindingHandler = keybindingHandler
        textView.vimModeHandler = vimModeHandler
        textView.documentURL = documentURL

        // Set the coordinator as delegate
        textView.delegate = context.coordinator

        // Store reference in coordinator
        context.coordinator.textView = textView

        // Notify that TextManipulating is ready
        onTextManipulatorReady?(textView)

        // Set the document view
        scrollView.documentView = textView

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? TymarkTextView else { return }

        // Update text if needed
        if textView.documentSource != text {
            textView.setMarkdown(text)
        }

        // Update theme if changed
        if viewModel.theme != context.coordinator.lastKnownTheme {
            textView.updateTheme(viewModel.theme)
            context.coordinator.lastKnownTheme = viewModel.theme
        }

        // Update source mode if changed
        if textView.isSourceModeEnabled != viewModel.isSourceMode {
            textView.setSourceMode(viewModel.isSourceMode)
        }

        if textView.keybindingHandler !== keybindingHandler {
            textView.keybindingHandler = keybindingHandler
        }

        if textView.vimModeHandler !== vimModeHandler {
            textView.vimModeHandler = vimModeHandler
        }

        // Update document URL for image paste
        textView.documentURL = documentURL

        // Update selection if needed
        let currentSelection = textView.selectedRange()
        if !NSEqualRanges(currentSelection, selection) {
            let maxLocation = (textView.string as NSString).length
            let safeLocation = max(0, min(selection.location, maxLocation))
            let safeLength = max(0, min(selection.length, maxLocation - safeLocation))
            textView.setSelectedRange(NSRange(location: safeLocation, length: safeLength))
        }
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    // MARK: - Coordinator

    @MainActor public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TymarkEditorView
        weak var textView: TymarkTextView?
        var lastKnownTheme: Theme?

        init(_ parent: TymarkEditorView) {
            self.parent = parent
            self.lastKnownTheme = parent.viewModel.theme
        }

        // MARK: - NSTextViewDelegate

        public func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }

            // Update the binding — we're already on main thread from NSTextViewDelegate
            self.parent.text = textView.documentSource
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = textView else { return }

            // Update the selection binding
            self.parent.selection = textView.selectedRange()

            // Notify view model
            parent.viewModel.selectionChanged(textView.selectedRange())
        }

        public func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Allow the change
            return true
        }
    }
}

// MARK: - Editor View Model

@MainActor
public final class EditorViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public var theme: Theme
    @Published public var isSourceMode: Bool = false
    @Published public var currentNode: TymarkNode?
    @Published public var wordCount: Int = 0
    @Published public var characterCount: Int = 0
    @Published public var isLoading: Bool = false

    // MARK: - Private Properties

    private var parser: IncrementalParser
    private var currentDocument: TymarkDocument?

    // MARK: - Callbacks

    public var onSelectionChange: ((NSRange) -> Void)?
    public var onNodeEnter: ((TymarkNode) -> Void)?
    public var onNodeExit: ((TymarkNode) -> Void)?

    // MARK: - Initialization

    public init(theme: Theme = BuiltInThemes.light) {
        self.theme = theme
        self.parser = IncrementalParser()
    }

    // MARK: - Public Methods

    public func setTheme(_ newTheme: Theme) {
        self.theme = newTheme
    }

    public func toggleSourceMode() {
        isSourceMode.toggle()
    }

    public func selectionChanged(_ range: NSRange) {
        onSelectionChange?(range)

        // Find the node at selection
        if let document = currentDocument,
           let node = document.root.node(at: range.location) {
            if node.id != currentNode?.id {
                if let previousNode = currentNode {
                    onNodeExit?(previousNode)
                }
                currentNode = node
                onNodeEnter?(node)
            }
        }
    }

    public func updateDocument(_ source: String) {
        currentDocument = parser.parse(source)
        updateStats(source: source)
    }

    public func export(to format: ExportFormat) -> Data? {
        guard let document = currentDocument else { return nil }

        switch format {
        case .html:
            return exportToHTML(document: document)
        case .pdf:
            return exportToPDF(document: document)
        case .docx:
            return exportToDOCX(document: document)
        }
    }

    // MARK: - Private Methods

    private func updateStats(source: String) {
        characterCount = (source as NSString).length
        wordCount = source.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private func exportToHTML(document: TymarkDocument) -> Data? {
        // Generate HTML from document
        let html = generateHTML(from: document)
        return html.data(using: .utf8)
    }

    private func exportToPDF(document: TymarkDocument) -> Data? {
        // PDF export would be implemented here
        return nil
    }

    private func exportToDOCX(document: TymarkDocument) -> Data? {
        // DOCX export would be implemented here
        return nil
    }

    private func generateHTML(from document: TymarkDocument) -> String {
        var html = "<!DOCTYPE html>\n<html>\n<head>\n"
        html += "<meta charset=\"UTF-8\">\n"
        html += "<title>Tymark Export</title>\n"
        html += "<style>\n"
        html += generateCSS()
        html += "</style>\n"
        html += "</head>\n<body>\n"

        html += convertNodeToHTML(document.root)

        html += "</body>\n</html>"

        return html
    }

    private func generateCSS() -> String {
        return """
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 1.5em;
            margin-bottom: 0.5em;
        }
        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
        }
        pre {
            background: #f4f4f4;
            padding: 16px;
            border-radius: 6px;
            overflow-x: auto;
        }
        blockquote {
            border-left: 4px solid #ddd;
            margin: 0;
            padding-left: 16px;
            color: #666;
        }
        """
    }

    private func convertNodeToHTML(_ node: TymarkNode) -> String {
        switch node.type {
        case .document:
            return node.children.map(convertNodeToHTML).joined()

        case .paragraph:
            let content = node.children.map(convertNodeToHTML).joined()
            return "<p>\(content)</p>\n"

        case .heading(let level):
            let content = node.children.map(convertNodeToHTML).joined()
            return "<h\(level)>\(content)</h\(level)>\n"

        case .blockquote:
            let content = node.children.map(convertNodeToHTML).joined()
            return "<blockquote>\(content)</blockquote>\n"

        case .list(let ordered):
            let tag = ordered ? "ol" : "ul"
            let content = node.children.map(convertNodeToHTML).joined()
            return "<\(tag)>\(content)</\(tag)>\n"

        case .listItem:
            let content = node.children.map(convertNodeToHTML).joined()
            return "<li>\(content)</li>\n"

        case .codeBlock:
            let language = node.codeLanguage ?? ""
            let content = escapeHTML(node.content)
            return "<pre><code class=\"language-\(language)\">\(content)</code></pre>\n"

        case .inlineCode:
            return "<code>\(escapeHTML(node.content))</code>"

        case .emphasis:
            let content = node.children.map(convertNodeToHTML).joined()
            return "<em>\(content)</em>"

        case .strong:
            let content = node.children.map(convertNodeToHTML).joined()
            return "<strong>\(content)</strong>"

        case .link(let destination, _):
            let content = node.children.map(convertNodeToHTML).joined()
            return "<a href=\"\(escapeHTML(destination))\">\(content)</a>"

        case .image(let source, let alt):
            return "<img src=\"\(escapeHTML(source))\" alt=\"\(escapeHTML(alt ?? ""))\">"

        case .text:
            return escapeHTML(node.content)

        case .softBreak, .lineBreak:
            return "\n"

        case .thematicBreak:
            return "<hr>\n"

        case .strikethrough:
            let content = node.children.map(convertNodeToHTML).joined()
            return "<del>\(content)</del>"

        default:
            return node.children.map(convertNodeToHTML).joined()
        }
    }

    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - Export Format

public enum ExportFormat {
    case html
    case pdf
    case docx
}
