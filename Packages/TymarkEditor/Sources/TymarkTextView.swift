import Cocoa
import TymarkParser
import TymarkTheme

// MARK: - Tymark Text View

public final class TymarkTextView: NSTextView {

    // MARK: - Properties

    private let parserState: ParserState
    private var renderingContext: RenderingContext
    private let cursorTracker: CursorProximityTracker
    private var theme: Theme

    private var isRenderingInProgress = false
    private var pendingRender = false

    /// Zoom multiplier for font scaling. Persisted to UserDefaults.
    public var zoomMultiplier: CGFloat {
        get { UserDefaults.standard.double(forKey: "editorZoomMultiplier").nonZeroOr(1.0) }
        set { UserDefaults.standard.set(newValue, forKey: "editorZoomMultiplier") }
    }

    /// Smart typography handler for curly quotes, em-dashes, ellipsis.
    public let smartTypography = SmartTypographyHandler(
        isEnabled: UserDefaults.standard.bool(forKey: "enableSmartTypography")
    )

    /// Find and replace engine for Cmd+F support.
    public let findReplaceEngine = FindReplaceEngine()

    /// Image paste handler for pasting images from clipboard.
    public let imagePasteHandler = ImagePasteHandler()

    /// The URL of the current document (set by the coordinator).
    public var documentURL: URL?

    public weak var keybindingHandler: KeybindingHandler?
    public weak var vimModeHandler: VimModeHandler? {
        didSet {
            if oldValue?.textView === self {
                oldValue?.textView = nil
            }
            vimModeHandler?.textView = self
        }
    }

    // MARK: - Initialization

    public init(frame: NSRect, theme: Theme) {
        self.theme = theme
        self.parserState = ParserState()
        self.renderingContext = Self.makeRenderingContext(theme: theme)
        self.cursorTracker = CursorProximityTracker()

        // Configure text container
        let textContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false

        // Create layout manager
        let layoutManager = TymarkTextLayoutManager()
        layoutManager.addTextContainer(textContainer)

        // Create text storage
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        super.init(frame: frame, textContainer: textContainer)

        // Configure the text view
        self.isRichText = false
        self.importsGraphics = false
        self.isFieldEditor = false
        self.allowsUndo = true
        self.isContinuousSpellCheckingEnabled = true
        self.isGrammarCheckingEnabled = true
        self.usesFontPanel = true
        self.usesRuler = true
        self.smartInsertDeleteEnabled = true
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isAutomaticLinkDetectionEnabled = true
        self.isAutomaticTextReplacementEnabled = true
        self.isAutomaticSpellingCorrectionEnabled = true

        // Set up notifications
        setupNotifications()

        // Initialize cursor tracker
        cursorTracker.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChangeNotification(_:)),
            name: NSText.didChangeNotification,
            object: self
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChangeNotification(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: self
        )
    }

    // MARK: - Public API

    public func setMarkdown(_ source: String) {
        parserState.setSource(source)
        renderDocument()
    }

    public func updateTheme(_ newTheme: Theme) {
        self.theme = newTheme
        self.renderingContext = Self.makeRenderingContext(theme: newTheme)
        renderDocument()
    }

    public var documentSource: String {
        return string
    }

    // MARK: - Rendering

    private func renderDocument() {
        guard !isRenderingInProgress else {
            pendingRender = true
            return
        }

        isRenderingInProgress = true

        // Convert AST to attributed string
        let converter = ASTToAttributedString(context: renderingContext)
        let attributedString = converter.convert(parserState.document)

        // Replace content while preserving selection if possible
        let previousSelection = self.selectedRange()

        self.textStorage?.setAttributedString(attributedString)

        // Restore selection safely by clamping location/length separately.
        let maxLocation = attributedString.length
        let safeLocation = max(0, min(previousSelection.location, maxLocation))
        let safeLength = max(0, min(previousSelection.length, maxLocation - safeLocation))
        self.setSelectedRange(NSRange(location: safeLocation, length: safeLength))

        isRenderingInProgress = false

        if pendingRender {
            pendingRender = false
            renderDocument()
        }
    }

    private func renderIncremental(at editRange: NSRange) {
        // Parse the edit
        let edit = TextEdit(range: editRange, replacement: "")
        let updateInfo = parserState.applyEdit(edit, to: string)

        // If it's a structural change, do a full re-render
        if updateInfo.isStructuralChange {
            renderDocument()
            return
        }

        // Otherwise, update just the affected range
        let converter = ASTToAttributedString(context: renderingContext)

        for node in updateInfo.nodesToReparse {
            let attributedNode = converter.convertNode(node, source: string)
            // Replace the range in text storage
            if NSMaxRange(node.range) <= (textStorage?.length ?? 0) {
                textStorage?.replaceCharacters(in: node.range, with: attributedNode)
            }
        }
    }

    // MARK: - Cursor Proximity

    private func updateCursorProximity() {
        let cursorLocation = selectedRange().location
        cursorTracker.updateCursorLocation(cursorLocation)

        // Find nodes near cursor that should show/hide syntax
        toggleSyntaxVisibility(at: cursorLocation)
    }

    private func toggleSyntaxVisibility(at location: Int) {
        // Find the node at cursor location
        guard let node = parserState.node(at: location) else { return }

        // If the node is inline-rendered, toggle source mode for it
        let needsSourceMode = shouldShowSourceMode(for: node, at: location)

        // Apply the visibility change
        applySyntaxVisibility(node: node, showSource: needsSourceMode)
    }

    private func shouldShowSourceMode(for node: TymarkNode, at location: Int) -> Bool {
        // Show source mode if cursor is inside the node
        return NSLocationInRange(location, node.range)
    }

    private func applySyntaxVisibility(node: TymarkNode, showSource: Bool) {
        // This would toggle the visibility of markdown syntax characters
        // by updating the attributed string attributes

        guard let textStorage = self.textStorage else { return }
        guard node.range.location < textStorage.length else { return }

        // Get current attributes
        let currentAttributes = textStorage.attributes(at: node.range.location, effectiveRange: nil)
        let currentSourceMode = currentAttributes[TymarkRenderingAttribute.isSyntaxHiddenKey] as? Bool ?? false

        // Only update if there's a change
        if currentSourceMode != showSource {
            textStorage.beginEditing()

            // Update the node content to show/hide syntax
            let converter = ASTToAttributedString(context: renderingContext)
            let newAttributed = converter.convertNode(node, source: string)

            // Replace the range
            if NSMaxRange(node.range) <= textStorage.length {
                textStorage.replaceCharacters(in: node.range, with: newAttributed)
            }

            textStorage.endEditing()
        }
    }

    // MARK: - Notifications

    @objc private func textDidChangeNotification(_ notification: Notification) {
        // Debounce rapid edits
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(processPendingEdits), object: nil)
        perform(#selector(processPendingEdits), with: nil, afterDelay: 0.016) // ~60fps
    }

    @objc private func processPendingEdits() {
        // Get the current string and re-parse
        let currentString = string

        // Update parser state
        parserState.setSource(currentString)

        // Re-render
        renderDocument()
    }

    @objc private func selectionDidChangeNotification(_ notification: Notification) {
        updateCursorProximity()
    }

    // MARK: - Overrides

    public override func keyDown(with event: NSEvent) {
        if vimModeHandler?.handleKeyEvent(event) == true {
            return
        }

        if keybindingHandler?.handleKeyEvent(event) == true {
            return
        }

        super.keyDown(with: event)
    }

    public override func paste(_ sender: Any?) {
        // Phase 7: Check for image paste
        if imagePasteHandler.pasteboardContainsImage() {
            let handled = imagePasteHandler.handleImagePaste(documentURL: documentURL) { [weak self] markdown in
                self?.insertAtCursor(markdown)
            }
            if handled { return }
        }
        super.paste(sender)
    }

    public override func insertText(_ insertString: Any, replacementRange: NSRange) {
        // Smart typography interception
        if let inputStr = insertString as? String, inputStr.count == 1 {
            let cursorLoc = selectedRange().location
            let isInCode = parserState.node(at: cursorLoc).map { node -> Bool in
                if case .codeBlock = node.type { return true }
                if case .inlineCode = node.type { return true }
                return false
            } ?? false

            let textBefore = cursorLoc > 0
                ? (string as NSString).substring(to: cursorLoc)
                : ""

            if let replacement = smartTypography.transform(inputStr, textBefore: textBefore, isInCodeBlock: isInCode) {
                // Handle em-dash: replace previous dash + current with single atomic operation
                if inputStr == "-" && textBefore.hasSuffix("-") {
                    let replaceRange = NSRange(location: cursorLoc - 1, length: 1)
                    super.insertText(replacement, replacementRange: replaceRange)
                    return
                }
                // Handle ellipsis: replace previous two dots + current with single atomic operation
                if inputStr == "." && textBefore.hasSuffix("..") {
                    let replaceRange = NSRange(location: cursorLoc - 2, length: 2)
                    super.insertText(replacement, replacementRange: replaceRange)
                    return
                }
                // Quotes: just replace the character
                super.insertText(replacement, replacementRange: replacementRange)
                return
            }
        }

        super.insertText(insertString, replacementRange: replacementRange)

        // Handle smart pairs and lists
        if let string = insertString as? String {
            handleSmartInsertion(of: string)
        }
    }

    public override func doCommand(by selector: Selector) {
        // Handle command shortcuts
        if selector == #selector(insertNewline(_:)) {
            if !handleNewline() {
                super.doCommand(by: selector)
            }
        } else {
            super.doCommand(by: selector)
        }
    }

    // MARK: - Smart Insertion Handlers

    private func handleSmartInsertion(of string: String) {
        // Handle smart pairs
        switch string {
        case "(":
            insertMatchingPair(closing: ")")
        case "[":
            insertMatchingPair(closing: "]")
        case "{":
            insertMatchingPair(closing: "}")
        case "\"":
            insertMatchingPair(closing: "\"")
        case "'":
            insertMatchingPair(closing: "'")
        case "`":
            handleBacktickInsertion()
        case "*", "_":
            handleEmphasisMarker(string)
        case "-":
            handleListMarker()
        default:
            break
        }
    }

    private func insertMatchingPair(closing: String) {
        let currentRange = selectedRange()
        super.insertText(closing, replacementRange: NSRange(location: currentRange.location, length: 0))
        setSelectedRange(currentRange)
    }

    private func handleBacktickInsertion() {
        // Check if we're in a code block or inline code
        let location = selectedRange().location
        if let node = parserState.node(at: location),
           case .inlineCode = node.type {
            // Already in inline code, don't add extra backticks
        }
    }

    private func handleEmphasisMarker(_ marker: String) {
        // Check if this is the second marker in a row (for ** / __).
        let location = selectedRange().location
        let previousChar = location > 1 ? string.charAt(location - 2) : nil

        if previousChar == marker.first {
            // Double marker = strong, insert closing pair
            insertMatchingPair(closing: String(repeating: marker, count: 2))
        } else {
            // Single marker = emphasis, insert closing pair
            insertMatchingPair(closing: marker)
        }
    }

    private func handleListMarker() {
        // Check if we're at the start of a line and should create a list
        let location = selectedRange().location
        let lineStart = string.lineStart(before: location)

        if location == lineStart || (location == lineStart + 1 && string.charAt(lineStart) == " ") {
            // At start of line - check context
            if let node = parserState.block(at: location),
               case .list = node.type {
                // Already in a list, continue it
            }
        }
    }

    @discardableResult
    private func handleNewline() -> Bool {
        let location = selectedRange().location

        // Check if we're in a list and should continue it
        if let node = parserState.block(at: location),
           case .list(let ordered) = node.type {
            // Continue the list with appropriate marker
            let marker = ordered ? "1. " : "- "
            insertText("\n" + marker, replacementRange: selectedRange())
            return true
        }

        return false
    }

    /// Applies the current zoom level by scaling fonts in the rendering context and re-rendering.
    func applyZoom() {
        self.renderingContext = Self.makeRenderingContext(theme: theme, zoom: zoomMultiplier)
        renderDocument()
    }

    private static func makeRenderingContext(theme: Theme) -> RenderingContext {
        return makeRenderingContext(theme: theme, zoom: UserDefaults.standard.double(forKey: "editorZoomMultiplier").nonZeroOr(1.0))
    }

    private static func makeRenderingContext(theme: Theme, zoom: CGFloat) -> RenderingContext {
        let bodyFont = theme.fonts.body.nsFont
        let codeFont = theme.fonts.code.nsFont
        let scaledBody = NSFont(descriptor: bodyFont.fontDescriptor, size: bodyFont.pointSize * zoom) ?? bodyFont
        let scaledCode = NSFont(descriptor: codeFont.fontDescriptor, size: codeFont.pointSize * zoom) ?? codeFont

        return RenderingContext(
            isSourceMode: false,
            baseFont: scaledBody,
            baseColor: theme.colors.text.nsColor,
            codeFont: scaledCode,
            linkColor: theme.colors.link.nsColor,
            syntaxHiddenColor: theme.colors.syntaxHidden.nsColor,
            codeBackgroundColor: theme.colors.codeBackground.nsColor,
            blockquoteColor: theme.colors.secondaryText.nsColor
        )
    }
}

// MARK: - Cursor Proximity Tracker Delegate

@MainActor
extension TymarkTextView: CursorProximityTrackerDelegate {
    public func cursorProximityTracker(_ tracker: CursorProximityTracker, didUpdateLocation location: Int) {
        // Intentionally empty: updateCursorProximity() already drives the tracker,
        // so calling it again here would cause infinite recursion.
        toggleSyntaxVisibility(at: location)
    }
}

// MARK: - String Extensions (UTF-16 safe for NSRange compatibility)

extension String {
    /// Returns the character at the given UTF-16 offset, or nil if out of bounds.
    func charAt(_ utf16Offset: Int) -> Character? {
        let nsString = self as NSString
        guard utf16Offset >= 0 && utf16Offset < nsString.length else { return nil }
        // Use composed character sequence to handle surrogate pairs
        let adjustedRange = nsString.rangeOfComposedCharacterSequence(at: utf16Offset)
        guard let swiftRange = Range(adjustedRange, in: self) else { return nil }
        return self[swiftRange].first
    }

    /// Returns the UTF-16 offset of the start of the line containing `location`.
    func lineStart(before location: Int) -> Int {
        let nsString = self as NSString
        let clampedLocation = min(location, nsString.length)
        let searchRange = NSRange(location: 0, length: clampedLocation)
        let newlineRange = nsString.range(of: "\n", options: .backwards, range: searchRange)
        if newlineRange.location != NSNotFound {
            return newlineRange.location + 1
        }
        return 0
    }
}

// MARK: - Double Extension

extension Double {
    /// Returns self if non-zero, otherwise the fallback value.
    func nonZeroOr(_ fallback: Double) -> Double {
        return self == 0 ? fallback : self
    }
}
