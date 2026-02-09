import Cocoa
import TymarkParser
import TymarkTheme

// MARK: - Tymark Text View

public final class TymarkTextView: NSTextView {

    // MARK: - Properties

    private let parserState: ParserState
    private let renderingContext: RenderingContext
    private let cursorTracker: CursorProximityTracker
    private var theme: Theme

    private var isRenderingInProgress = false
    private var pendingRender = false

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
        self.renderingContext = RenderingContext(
            isSourceMode: false,
            baseFont: theme.fonts.body.nsFont,
            baseColor: theme.colors.text.nsColor,
            codeFont: theme.fonts.code.nsFont,
            linkColor: theme.colors.link.nsColor,
            syntaxHiddenColor: theme.colors.syntaxHidden.nsColor,
            codeBackgroundColor: theme.colors.codeBackground.nsColor,
            blockquoteColor: theme.colors.secondaryText.nsColor
        )
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
        // Update rendering context with new theme
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
        let selectedRange = self.selectedRange()

        self.textStorage?.setAttributedString(attributedString)

        // Restore selection safely — clamp to valid range
        let maxRange = NSRange(location: 0, length: attributedString.length)
        let safeRange = NSIntersectionRange(selectedRange, maxRange)
        if safeRange.length > 0 || (safeRange.location < attributedString.length) {
            self.setSelectedRange(safeRange)
        } else if attributedString.length > 0 {
            self.setSelectedRange(NSRange(location: attributedString.length, length: 0))
        }

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

    public override func insertText(_ insertString: Any, replacementRange: NSRange) {
        super.insertText(insertString, replacementRange: replacementRange)

        // Handle smart pairs and lists
        if let string = insertString as? String {
            handleSmartInsertion(of: string)
        }
    }

    public override func doCommand(by selector: Selector) {
        // Handle command shortcuts
        if selector == #selector(insertNewline(_:)) {
            handleNewline()
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
        insertText(closing, replacementRange: NSRange(location: currentRange.location, length: 0))
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
        // Check if we should auto-close emphasis
        let location = selectedRange().location
        let prevChar = location > 0 ? string.charAt(location - 1) : nil

        if prevChar == marker.first {
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

    private func handleNewline() {
        let location = selectedRange().location

        // Check if we're in a list and should continue it
        if let node = parserState.block(at: location),
           case .list(let ordered) = node.type {
            // Continue the list with appropriate marker
            let marker = ordered ? "1. " : "- "
            insertText("\n" + marker, replacementRange: selectedRange())
        }
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
