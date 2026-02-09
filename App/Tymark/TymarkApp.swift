import SwiftUI
import UniformTypeIdentifiers
import TymarkParser
import TymarkEditor
import TymarkTheme
import TymarkWorkspace
import TymarkSync
import TymarkExport
import TymarkAI

// MARK: - Tymark App

@main
struct TymarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appState = AppState()

    var body: some Scene {
        DocumentGroup(newDocument: { TymarkDocumentModel() }) { configuration in
            ContentView(document: configuration.document, fileURL: configuration.fileURL)
                .environmentObject(appState)
        }
        .commands {
            TymarkCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var themeManager = ThemeManager.shared
    @Published var workspaceManager = WorkspaceManager()
    @Published var syncStatusTracker = SyncStatusTracker()
    @Published var networkMonitor = NetworkMonitor()
    @Published var isSidebarVisible = true
    @Published var isCommandPaletteVisible = false
    @Published var isQuickOpenVisible = false
    @Published var isConflictSheetVisible = false
    @Published var conflictVersions: [NSFileVersion] = []
    @Published var conflictDocumentURL: URL?
    @Published var exportError: String?
    @Published var pendingExportFormat: String?
    @Published var isFocusModeEnabled = false
    @Published var sourceModeShouldToggle = false

    // Phase 6: Zen mode, Find/Replace, Statistics
    @Published var isZenModeEnabled = false
    @Published var isFindBarVisible = false
    @Published var isStatisticsBarVisible = false
    @Published var documentStatistics = DocumentStatistics()
    let zenModeController = ZenModeController()

    // Phase 8: AI Writing Assistant
    @Published var aiAssistantState = AIAssistantState()
    let aiConfiguration = AIConfiguration()
    let aiPrivacyManager = AIPrivacyManager()

    /// Reference to the active text manipulator (the focused TymarkTextView).
    weak var activeTextManipulator: (any TextManipulating)?

    let spotlightIndexer = SpotlightIndexer()
    let exportManager = ExportManager()
    lazy var cloudSyncManager: TymarkSync.iCloudSyncManager = {
        TymarkSync.iCloudSyncManager(syncStatusTracker: syncStatusTracker, networkMonitor: networkMonitor)
    }()
    let versionManager = DocumentVersionManager()

    // Phase 4: Command & Keybinding System
    let commandRegistry = CommandRegistry()
    let keybindingHandler: KeybindingHandler
    let keybindingLoader = KeybindingLoader()
    @Published var vimModeHandler = VimModeHandler()

    init() {
        let config = keybindingLoader.load()
        self.keybindingHandler = KeybindingHandler(configuration: config)

        networkMonitor.start()
        syncStatusTracker.configure(with: networkMonitor)
        commandRegistry.loadShortcutOverrides()

        registerCommands()
        keybindingHandler.setCommandRegistry(commandRegistry)
    }

    // MARK: - Command Registration

    private func registerCommands() {
        commandRegistry.register([
            // File commands
            CommandDefinition(
                id: "file.new",
                name: "New Document",
                category: .file,
                defaultShortcut: "cmd+n"
            ) { [weak self] in
                self?.sendAppAction("newDocument:")
            },

            CommandDefinition(
                id: "file.open",
                name: "Open Document",
                category: .file,
                defaultShortcut: "cmd+o"
            ) { [weak self] in
                self?.openDocument()
            },

            CommandDefinition(
                id: "file.save",
                name: "Save",
                category: .file,
                defaultShortcut: "cmd+s"
            ) { [weak self] in
                self?.sendAppAction("saveDocument:")
            },

            CommandDefinition(
                id: "file.saveAs",
                name: "Save As...",
                category: .file,
                defaultShortcut: "cmd+shift+s"
            ) { [weak self] in
                self?.sendAppAction("saveDocumentAs:")
            },

            CommandDefinition(
                id: "file.close",
                name: "Close",
                category: .file,
                defaultShortcut: "cmd+w"
            ) { [weak self] in
                self?.sendAppAction("performClose:")
            },

            // Edit commands
            CommandDefinition(
                id: "edit.undo",
                name: "Undo",
                category: .edit,
                defaultShortcut: "cmd+z"
            ) { [weak self] in
                self?.sendAppAction("undo:")
            },

            CommandDefinition(
                id: "edit.redo",
                name: "Redo",
                category: .edit,
                defaultShortcut: "cmd+shift+z"
            ) { [weak self] in
                self?.sendAppAction("redo:")
            },

            CommandDefinition(
                id: "edit.cut",
                name: "Cut",
                category: .edit,
                defaultShortcut: "cmd+x"
            ) { [weak self] in
                self?.sendAppAction("cut:")
            },

            CommandDefinition(
                id: "edit.copy",
                name: "Copy",
                category: .edit,
                defaultShortcut: "cmd+c"
            ) { [weak self] in
                self?.sendAppAction("copy:")
            },

            CommandDefinition(
                id: "edit.paste",
                name: "Paste",
                category: .edit,
                defaultShortcut: "cmd+v"
            ) { [weak self] in
                self?.sendAppAction("paste:")
            },

            CommandDefinition(
                id: "edit.selectAll",
                name: "Select All",
                category: .edit,
                defaultShortcut: "cmd+a"
            ) { [weak self] in
                self?.sendAppAction("selectAll:")
            },

            // View commands
            CommandDefinition(
                id: "view.commandPalette",
                name: "Command Palette",
                category: .view,
                defaultShortcut: "cmd+shift+p"
            ) { [weak self] in
                self?.isCommandPaletteVisible.toggle()
            },

            CommandDefinition(
                id: "view.quickOpen",
                name: "Quick Open",
                category: .view,
                defaultShortcut: "cmd+p"
            ) { [weak self] in
                self?.isQuickOpenVisible = true
            },

            CommandDefinition(
                id: "view.toggleSidebar",
                name: "Toggle Sidebar",
                category: .view,
                defaultShortcut: "cmd+shift+b"
            ) { [weak self] in
                self?.isSidebarVisible.toggle()
            },

            CommandDefinition(
                id: "view.toggleFocusMode",
                name: "Toggle Focus Mode",
                category: .view,
                defaultShortcut: "cmd+shift+f"
            ) { [weak self] in
                self?.isFocusModeEnabled.toggle()
            },

            CommandDefinition(
                id: "view.toggleSourceMode",
                name: "Toggle Source Mode",
                category: .view,
                defaultShortcut: "cmd+/"
            ) { [weak self] in
                // Source mode toggled via EditorViewModel in ContentView
                self?.sourceModeShouldToggle = true
            },

            CommandDefinition(
                id: "view.zoomIn",
                name: "Zoom In",
                category: .view,
                defaultShortcut: "cmd+="
            ) { [weak self] in
                self?.activeTextManipulator?.zoomIn()
            },

            CommandDefinition(
                id: "view.zoomOut",
                name: "Zoom Out",
                category: .view,
                defaultShortcut: "cmd+-"
            ) { [weak self] in
                self?.activeTextManipulator?.zoomOut()
            },

            CommandDefinition(
                id: "view.resetZoom",
                name: "Reset Zoom",
                category: .view,
                defaultShortcut: "cmd+0"
            ) { [weak self] in
                self?.activeTextManipulator?.resetZoom()
            },

            // Format commands
            CommandDefinition(
                id: "format.bold",
                name: "Bold",
                category: .format,
                defaultShortcut: "cmd+b"
            ) { [weak self] in
                self?.activeTextManipulator?.wrapSelection(prefix: "**", suffix: "**")
            },

            CommandDefinition(
                id: "format.italic",
                name: "Italic",
                category: .format,
                defaultShortcut: "cmd+i"
            ) { [weak self] in
                self?.activeTextManipulator?.wrapSelection(prefix: "*", suffix: "*")
            },

            CommandDefinition(
                id: "format.strikethrough",
                name: "Strikethrough",
                category: .format,
                defaultShortcut: "cmd+shift+x"
            ) { [weak self] in
                self?.activeTextManipulator?.wrapSelection(prefix: "~~", suffix: "~~")
            },

            CommandDefinition(
                id: "format.inlineCode",
                name: "Inline Code",
                category: .format,
                defaultShortcut: "cmd+e"
            ) { [weak self] in
                self?.activeTextManipulator?.wrapSelection(prefix: "`", suffix: "`")
            },

            CommandDefinition(
                id: "format.link",
                name: "Insert Link",
                category: .format,
                defaultShortcut: "cmd+k"
            ) { [weak self] in
                self?.activeTextManipulator?.insertLink(url: "https://")
            },

            CommandDefinition(
                id: "format.heading1",
                name: "Heading 1",
                category: .format,
                defaultShortcut: "cmd+1"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("# ")
            },

            CommandDefinition(
                id: "format.heading2",
                name: "Heading 2",
                category: .format,
                defaultShortcut: "cmd+2"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("## ")
            },

            CommandDefinition(
                id: "format.heading3",
                name: "Heading 3",
                category: .format,
                defaultShortcut: "cmd+3"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("### ")
            },

            CommandDefinition(
                id: "format.heading4",
                name: "Heading 4",
                category: .format,
                defaultShortcut: "cmd+4"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("#### ")
            },

            CommandDefinition(
                id: "format.heading5",
                name: "Heading 5",
                category: .format,
                defaultShortcut: "cmd+5"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("##### ")
            },

            CommandDefinition(
                id: "format.heading6",
                name: "Heading 6",
                category: .format,
                defaultShortcut: "cmd+6"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("###### ")
            },

            CommandDefinition(
                id: "format.orderedList",
                name: "Ordered List",
                category: .format,
                defaultShortcut: "cmd+shift+7"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("1. ")
            },

            CommandDefinition(
                id: "format.unorderedList",
                name: "Unordered List",
                category: .format,
                defaultShortcut: "cmd+shift+8"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("- ")
            },

            CommandDefinition(
                id: "format.taskList",
                name: "Task List",
                category: .format,
                defaultShortcut: "cmd+shift+9"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("- [ ] ")
            },

            CommandDefinition(
                id: "format.blockquote",
                name: "Blockquote",
                category: .format,
                defaultShortcut: "cmd+shift+."
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("> ")
            },

            CommandDefinition(
                id: "format.codeBlock",
                name: "Code Block",
                category: .format,
                defaultShortcut: "cmd+shift+c"
            ) { [weak self] in
                self?.activeTextManipulator?.insertAtCursor("\n```\n\n```\n")
            },

            CommandDefinition(
                id: "format.horizontalRule",
                name: "Horizontal Rule",
                category: .format,
                defaultShortcut: "cmd+shift+-"
            ) { [weak self] in
                self?.activeTextManipulator?.insertAtCursor("\n---\n")
            },

            // Navigate commands
            CommandDefinition(
                id: "navigate.moveLineUp",
                name: "Move Line Up",
                category: .navigate,
                defaultShortcut: "alt+up"
            ) { [weak self] in
                self?.activeTextManipulator?.moveLineUp()
            },

            CommandDefinition(
                id: "navigate.moveLineDown",
                name: "Move Line Down",
                category: .navigate,
                defaultShortcut: "alt+down"
            ) { [weak self] in
                self?.activeTextManipulator?.moveLineDown()
            },

            CommandDefinition(
                id: "navigate.duplicateLine",
                name: "Duplicate Line",
                category: .navigate,
                defaultShortcut: "cmd+shift+d"
            ) { [weak self] in
                self?.activeTextManipulator?.duplicateLine()
            },

            // Export commands
            CommandDefinition(
                id: "export.html",
                name: "Export as HTML",
                category: .export,
                defaultShortcut: "cmd+shift+e"
            ) { [weak self] in
                self?.pendingExportFormat = "html"
            },

            CommandDefinition(
                id: "export.pdf",
                name: "Export as PDF",
                category: .export,
                defaultShortcut: "cmd+alt+p"
            ) { [weak self] in
                self?.pendingExportFormat = "pdf"
            },

            CommandDefinition(
                id: "export.docx",
                name: "Export as Word",
                category: .export
            ) { [weak self] in
                self?.pendingExportFormat = "docx"
            },

            CommandDefinition(
                id: "export.rtf",
                name: "Export as RTF",
                category: .export
            ) { [weak self] in
                self?.pendingExportFormat = "rtf"
            },

            // Phase 6: Find & Replace commands
            CommandDefinition(
                id: "edit.find",
                name: "Find",
                category: .edit,
                defaultShortcut: "cmd+f"
            ) { [weak self] in
                self?.isFindBarVisible = true
            },

            CommandDefinition(
                id: "edit.findAndReplace",
                name: "Find and Replace",
                category: .edit,
                defaultShortcut: "cmd+h"
            ) { [weak self] in
                self?.isFindBarVisible = true
            },

            CommandDefinition(
                id: "edit.findNext",
                name: "Find Next",
                category: .edit,
                defaultShortcut: "cmd+g"
            ) { [weak self] in
                if let textView = self?.activeTextManipulator as? TymarkTextView {
                    textView.findReplaceEngine.findNext()
                }
            },

            CommandDefinition(
                id: "edit.findPrevious",
                name: "Find Previous",
                category: .edit,
                defaultShortcut: "cmd+shift+g"
            ) { [weak self] in
                if let textView = self?.activeTextManipulator as? TymarkTextView {
                    textView.findReplaceEngine.findPrevious()
                }
            },

            // Phase 6: Zen mode
            CommandDefinition(
                id: "view.zenMode",
                name: "Toggle Zen Mode",
                category: .view,
                defaultShortcut: "cmd+shift+return"
            ) { [weak self] in
                self?.isZenModeEnabled.toggle()
                self?.zenModeController.toggle(window: NSApp.keyWindow)
            },

            // Phase 6: Statistics
            CommandDefinition(
                id: "view.toggleStatistics",
                name: "Toggle Statistics Bar",
                category: .view
            ) { [weak self] in
                self?.isStatisticsBarVisible.toggle()
            },

            // Phase 8: AI commands
            CommandDefinition(
                id: "ai.togglePanel",
                name: "Toggle AI Assistant",
                category: .tools,
                defaultShortcut: "cmd+shift+a"
            ) { [weak self] in
                self?.aiAssistantState.isVisible.toggle()
            },

            CommandDefinition(
                id: "ai.complete",
                name: "AI: Complete",
                category: .tools
            ) { [weak self] in
                self?.runAITask(.complete)
            },

            CommandDefinition(
                id: "ai.summarize",
                name: "AI: Summarize",
                category: .tools
            ) { [weak self] in
                self?.runAITask(.summarize)
            },

            CommandDefinition(
                id: "ai.rewrite",
                name: "AI: Rewrite",
                category: .tools
            ) { [weak self] in
                self?.runAITask(.rewrite)
            },

            CommandDefinition(
                id: "ai.fixGrammar",
                name: "AI: Fix Grammar",
                category: .tools
            ) { [weak self] in
                self?.runAITask(.fixGrammar)
            },

            CommandDefinition(
                id: "ai.translate",
                name: "AI: Translate",
                category: .tools
            ) { [weak self] in
                self?.runAITask(.translate)
            },

            // Tools
            CommandDefinition(
                id: "tools.toggleVimMode",
                name: "Toggle Vim Mode",
                category: .tools
            ) { [weak self] in
                self?.vimModeHandler.isEnabled.toggle()
            },
        ])
    }

    private func sendAppAction(_ selector: String) {
        NSApp.sendAction(Selector(selector), to: nil, from: nil)
    }

    func openDocument() {
        NSDocumentController.shared.openDocument(nil)
    }

    func runAITask(_ taskType: AITaskType) {
        aiAssistantState.selectedTask = taskType
        aiAssistantState.isVisible = true

        if let manipulator = activeTextManipulator {
            let selected = manipulator.selectedText
            let context = manipulator.fullText
            aiAssistantState.run(
                text: selected.isEmpty ? context : selected,
                context: selected.isEmpty ? "" : context,
                configuration: aiConfiguration
            )
        }
    }
}

// MARK: - AI Assistant State (Phase 8)

@MainActor
final class AIAssistantState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var selectedTask: AITaskType = .complete
    @Published var responseText: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var cursorVisible: Bool = true
    @Published var isUsingCloud: Bool = false

    private var currentEngine: (any AIServiceProtocol)?
    private var cursorTimer: Timer?

    /// Callback to insert accepted text into the editor.
    var onAcceptResponse: ((String) -> Void)?

    init() {
        // Cursor blink timer
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cursorVisible.toggle()
            }
        }
    }

    deinit {
        cursorTimer?.invalidate()
    }

    func run(text: String, context: String, configuration: AIConfiguration) {
        guard !text.isEmpty else { return }

        responseText = ""
        errorMessage = nil
        isProcessing = true

        let engine: any AIServiceProtocol
        switch configuration.selectedEngine {
        case .cloud:
            if configuration.hasAPIKey {
                engine = CloudAIEngine(configuration: configuration)
                isUsingCloud = true
            } else {
                errorMessage = "API key not configured. Set your API key in Settings to use Cloud AI."
                isProcessing = false
                return
            }
        case .auto:
            if configuration.hasAPIKey {
                engine = CloudAIEngine(configuration: configuration)
                isUsingCloud = true
            } else {
                engine = LocalAIEngine()
                isUsingCloud = false
            }
        case .local:
            engine = LocalAIEngine()
            isUsingCloud = false
        }
        currentEngine = engine

        let request = AIRequest(
            taskType: selectedTask,
            inputText: text,
            context: context
        )

        Task {
            do {
                for try await response in engine.process(request) {
                    switch response.type {
                    case .partial(let text):
                        self.responseText = text
                    case .complete(let text):
                        self.responseText = text
                        self.isProcessing = false
                    case .error(let message):
                        self.errorMessage = message
                        self.isProcessing = false
                    }
                }
                self.isProcessing = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }

    func cancel() {
        currentEngine?.cancel()
        isProcessing = false
    }

    func acceptResponse() {
        onAcceptResponse?(responseText)
        responseText = ""
    }

    func discardResponse() {
        responseText = ""
        errorMessage = nil
    }
}

// MARK: - Document Model (ReferenceFileDocument)

// @unchecked Sendable: Safe because ReferenceFileDocument is always accessed
// from the main thread by SwiftUI's document infrastructure.
final class TymarkDocumentModel: ReferenceFileDocument, @unchecked Sendable {

    @Published var content: String {
        didSet {
            updateMetadata()
        }
    }
    @Published var metadata: DocumentMetadata

    init(content: String = "") {
        self.content = content
        self.metadata = DocumentMetadata()
        updateMetadata()
    }

    private func updateMetadata() {
        metadata.modifiedAt = Date()
        metadata.characterCount = (content as NSString).length
        metadata.wordCount = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        metadata.title = MarkdownContentHelpers.extractTitle(from: content)
    }

    // MARK: - ReferenceFileDocument

    static var readableContentTypes: [UTType] {
        var types: Set<UTType> = [.plainText, .markdown]
        ["md", "markdown", "mdown", "mkd"].forEach { ext in
            if let type = UTType(filenameExtension: ext) {
                types.insert(type)
            }
        }
        return Array(types)
    }

    static var writableContentTypes: [UTType] {
        var types: Set<UTType> = [.plainText, .markdown]
        if let mdType = UTType(filenameExtension: "md") {
            types.insert(mdType)
        }
        return Array(types)
    }

    convenience init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.init(content: string)
    }

    func snapshot(contentType: UTType) throws -> String {
        return content
    }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = snapshot.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Focused Values for Export

struct ExportActionKey: FocusedValueKey {
    typealias Value = (String) -> Void
}

extension FocusedValues {
    var exportAction: ExportActionKey.Value? {
        get { self[ExportActionKey.self] }
        set { self[ExportActionKey.self] = newValue }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var document: TymarkDocumentModel
    var fileURL: URL?

    @State private var selection = NSRange(location: 0, length: 0)
    @StateObject private var editorViewModel = EditorViewModel()

    var body: some View {
        NavigationSplitView {
            if appState.isSidebarVisible {
                SidebarView()
                    .environmentObject(appState.workspaceManager)
            }
        } detail: {
            VStack(spacing: 0) {
                // Find/Replace bar (Phase 6)
                if appState.isFindBarVisible,
                   let textView = appState.activeTextManipulator as? TymarkTextView {
                    FindReplaceBar(
                        engine: textView.findReplaceEngine,
                        isVisible: $appState.isFindBarVisible
                    )
                }

                ZStack(alignment: .bottom) {
                    TymarkEditorView(
                        text: $document.content,
                        selection: $selection,
                        viewModel: editorViewModel,
                        keybindingHandler: appState.keybindingHandler,
                        vimModeHandler: appState.vimModeHandler,
                        onTextManipulatorReady: { manipulator in
                            appState.activeTextManipulator = manipulator
                            // Attach find engine to the text view
                            if let tv = manipulator as? TymarkTextView {
                                tv.findReplaceEngine.attach(to: tv)
                            }
                        },
                        documentURL: fileURL
                    )
                    .frame(minWidth: 400, minHeight: 300)

                    // Vim mode status bar
                    if appState.vimModeHandler.isEnabled {
                        VimStatusBar(handler: appState.vimModeHandler)
                    }
                }

                // Statistics bar (Phase 6)
                if appState.isStatisticsBarVisible {
                    DocumentStatisticsBar(statistics: appState.documentStatistics)
                }
            }

            // AI Assistant Panel (Phase 8)
            if appState.aiAssistantState.isVisible {
                AIAssistantPanel(state: appState.aiAssistantState)
                    .environmentObject(appState)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                HStack {
                    Button(action: { appState.isSidebarVisible.toggle() }) {
                        Image(systemName: appState.isSidebarVisible ? "sidebar.left" : "sidebar.left.fill")
                    }

                    Button(action: { appState.openDocument() }) {
                        Image(systemName: "folder")
                    }
                    .help("Open Document")

                    Spacer()

                    // Sync status indicator
                    SyncStatusView(tracker: appState.syncStatusTracker)

                    Menu {
                        ForEach(appState.themeManager.availableThemes, id: \.id) { theme in
                            Button(theme.name) {
                                appState.themeManager.setTheme(theme)
                                editorViewModel.setTheme(theme)
                            }
                        }
                    } label: {
                        Image(systemName: "paintbrush")
                    }

                    // Export menu
                    Menu {
                        Button("Export as HTML...") {
                            exportDocument(format: "html")
                        }
                        Button("Export as PDF...") {
                            exportDocument(format: "pdf")
                        }
                        Button("Export as Word (.docx)...") {
                            exportDocument(format: "docx")
                        }
                        Button("Export as RTF...") {
                            exportDocument(format: "rtf")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button(action: { appState.isCommandPaletteVisible.toggle() }) {
                        Image(systemName: "command")
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                }
            }
        }
        .focusedValue(\.exportAction, exportDocument)
        .sheet(isPresented: $appState.isCommandPaletteVisible) {
            CommandPaletteView(
                isVisible: $appState.isCommandPaletteVisible,
                registry: appState.commandRegistry
            )
        }
        .sheet(isPresented: $appState.isQuickOpenVisible) {
            QuickOpenView(isVisible: $appState.isQuickOpenVisible)
                .environmentObject(appState.workspaceManager)
        }
        .sheet(isPresented: $appState.isConflictSheetVisible) {
            ConflictResolutionView(
                versions: appState.conflictVersions,
                isVisible: $appState.isConflictSheetVisible,
                onResolve: { keepLocal in
                    if let url = appState.conflictDocumentURL {
                        appState.cloudSyncManager.resolveConflicts(for: url, keepingCurrent: keepLocal)
                    }
                }
            )
        }
        .alert("Export Error", isPresented: Binding(
            get: { appState.exportError != nil },
            set: { if !$0 { appState.exportError = nil } }
        )) {
            Button("OK") { appState.exportError = nil }
        } message: {
            Text(appState.exportError ?? "")
        }
        .onAppear {
            editorViewModel.setTheme(appState.themeManager.currentTheme)
            // Wire AI accept response callback
            appState.aiAssistantState.onAcceptResponse = { [weak appState] text in
                appState?.activeTextManipulator?.insertAtCursor(text)
            }
        }
        .onChange(of: document.content) { _, newValue in
            // Index updated content in Spotlight using real document URL
            if let url = fileURL {
                appState.spotlightIndexer.indexDocument(
                    at: url,
                    content: newValue,
                    title: document.metadata.title
                )
            }
            // Update statistics (Phase 6)
            appState.documentStatistics = DocumentStatisticsEngine.compute(from: newValue)
        }
        .onChange(of: appState.pendingExportFormat) { _, newValue in
            guard let format = newValue else { return }
            exportDocument(format: format)
            appState.pendingExportFormat = nil
        }
        .onChange(of: appState.sourceModeShouldToggle) { _, newValue in
            if newValue {
                editorViewModel.toggleSourceMode()
                appState.sourceModeShouldToggle = false
            }
        }
    }

    // MARK: - Export

    private func exportDocument(format: String) {
        let parser = MarkdownParser()
        let parsedDoc = parser.parse(document.content)
        let theme = appState.themeManager.currentTheme

        guard let data = appState.exportManager.export(
            document: parsedDoc,
            format: format,
            theme: theme
        ) else {
            appState.exportError = "Failed to generate \(format.uppercased()) export."
            return
        }

        let panel = NSSavePanel()
        let docTitle = document.metadata.title ?? "Export"
        panel.nameFieldStringValue = "\(docTitle).\(format)"

        switch format {
        case "html":
            panel.allowedContentTypes = [UTType.html]
        case "pdf":
            panel.allowedContentTypes = [UTType.pdf]
        case "docx":
            panel.allowedContentTypes = [UTType(filenameExtension: "docx")!]
        case "rtf":
            panel.allowedContentTypes = [UTType.rtf]
        default:
            break
        }

        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                Task { @MainActor in
                    appState.exportError = "Failed to save file: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Vim Status Bar

struct VimStatusBar: View {
    @ObservedObject var handler: VimModeHandler

    var body: some View {
        HStack {
            Text(handler.statusMessage)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Text(handler.mode.rawValue.uppercased())
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(modeColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.85))
    }

    private var modeColor: Color {
        switch handler.mode {
        case .normal: return .green
        case .insert: return .blue
        case .visual: return .orange
        case .command: return .yellow
        }
    }
}

// MARK: - Sync Status View

struct SyncStatusView: View {
    @ObservedObject var tracker: SyncStatusTracker

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tracker.status.systemImageName)
                .font(.caption)
                .foregroundColor(statusColor)

            if tracker.status.isPending {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
        }
        .help(tracker.status.description)
    }

    private var statusColor: Color {
        switch tracker.status {
        case .synced: return .green
        case .syncing, .pendingUpload, .pendingDownload: return .blue
        case .conflict: return .orange
        case .error: return .red
        case .offline: return .gray
        }
    }
}

// MARK: - Conflict Resolution View

struct ConflictResolutionView: View {
    let versions: [NSFileVersion]
    @Binding var isVisible: Bool
    let onResolve: (Bool) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Document Conflict")
                .font(.headline)

            Text("This document has been modified in multiple locations. Choose which version to keep.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let latestConflict = versions.sorted(by: {
                ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
            }).first {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Local version")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    HStack {
                        Text("Remote version")
                            .fontWeight(.medium)
                        Spacer()
                        if let date = latestConflict.modificationDate {
                            Text(date, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let device = latestConflict.localizedNameOfSavingComputer {
                            Text("from \(device)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }

            HStack(spacing: 12) {
                Button("Keep Local") {
                    onResolve(true)
                    isVisible = false
                }
                .keyboardShortcut(.defaultAction)

                Button("Keep Remote") {
                    onResolve(false)
                    isVisible = false
                }

                Button("Cancel") {
                    isVisible = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 450)
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @EnvironmentObject var workspaceManager: WorkspaceManager

    var body: some View {
        List {
            if let workspace = workspaceManager.currentWorkspace {
                Section(header: Text(workspace.name)) {
                    FileTreeView(files: workspace.openFiles)
                }
            }

            Section(header: Text("Recent")) {
                ForEach(workspaceManager.currentWorkspace?.recentFiles ?? [], id: \.self) { url in
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}

// MARK: - File Tree View

struct FileTreeView: View {
    let files: [WorkspaceFile]

    var body: some View {
        ForEach(files) { file in
            FileRow(file: file)
        }
    }
}

// MARK: - File Row

struct FileRow: View {
    let file: WorkspaceFile
    @EnvironmentObject var workspaceManager: WorkspaceManager

    var body: some View {
        HStack {
            Image(systemName: file.isDirectory ? "folder" : "doc.text")
                .foregroundColor(file.isDirectory ? .blue : .gray)

            Text(file.name)
                .lineLimit(1)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if file.isDirectory {
                // Toggle expansion
            } else {
                workspaceManager.selectFile(file)
            }
        }
    }
}

// MARK: - Command Palette View (Phase 4: Wired to CommandRegistry)

struct CommandPaletteView: View {
    @Binding var isVisible: Bool
    @ObservedObject var registry: CommandRegistry
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFieldFocused: Bool

    var filteredCommands: [CommandDefinition] {
        registry.search(query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Type a command...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        executeSelectedCommand()
                    }

                Button {
                    isVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))

            Divider()

            // Command list
            ScrollViewReader { proxy in
                List(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                    CommandPaletteRow(
                        command: command,
                        shortcut: registry.shortcut(for: command.id),
                        isSelected: index == selectedIndex,
                        isEnabled: command.isEnabled()
                    )
                    .id(command.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if registry.execute(command.id) {
                            isVisible = false
                        }
                    }
                }
                .listStyle(.plain)
                .onChange(of: selectedIndex) { _, newValue in
                    if newValue < filteredCommands.count {
                        proxy.scrollTo(filteredCommands[newValue].id, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 550, height: 420)
        .onAppear {
            isSearchFieldFocused = true
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredCommands.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            isVisible = false
            return .handled
        }
    }

    private func executeSelectedCommand() {
        guard selectedIndex < filteredCommands.count else { return }
        let selected = filteredCommands[selectedIndex]
        if registry.execute(selected.id) {
            isVisible = false
        }
    }
}

// MARK: - Command Palette Row

struct CommandPaletteRow: View {
    let command: CommandDefinition
    let shortcut: String?
    let isSelected: Bool
    let isEnabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(command.name)
                    .font(.system(size: 13))
                Text(command.category.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let shortcut = shortcut {
                Text(KeyComboParser.displayString(for: shortcut))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.separatorColor).opacity(0.3))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Quick Open View

struct QuickOpenView: View {
    @Binding var isVisible: Bool
    @EnvironmentObject var workspaceManager: WorkspaceManager
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFieldFocused: Bool

    private let searchEngine = FuzzySearchEngine()
    @State private var isIndexed = false

    var searchResults: [SearchResult] {
        guard !searchText.isEmpty, isIndexed else { return [] }
        return searchEngine.quickOpen(query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        openSelectedFile()
                    }
                Button {
                    isVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))

            Divider()

            // Results list
            if searchText.isEmpty {
                // Show recent files
                List {
                    Section(header: Text("Recent Files").font(.caption)) {
                        ForEach(workspaceManager.currentWorkspace?.recentFiles ?? [], id: \.self) { url in
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.secondary)
                                Text(url.lastPathComponent)
                                Spacer()
                                Text(url.deletingLastPathComponent().lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                NSDocumentController.shared.openDocument(
                                    withContentsOf: url,
                                    display: true
                                ) { _, _, _ in }
                                isVisible = false
                            }
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                let results = searchResults
                if results.isEmpty {
                    VStack {
                        Spacer()
                        Text("No files found")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(Array(results.enumerated()), id: \.element.id) { index, result in
                        HStack {
                            Image(systemName: result.file.isDirectory ? "folder" : "doc.text")
                                .foregroundColor(result.file.isDirectory ? .blue : .secondary)
                            Text(result.file.name)
                                .font(.system(size: 13))
                            Spacer()
                            Text(String(format: "%.0f%%", result.score * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                        .background(index == selectedIndex ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openFile(result.file)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .frame(width: 550, height: 400)
        .onAppear {
            isSearchFieldFocused = true
            searchEngine.index(workspaceManager.currentWorkspace?.openFiles ?? [])
            isIndexed = true
        }
        .onChange(of: workspaceManager.currentWorkspace?.openFiles) { _, newFiles in
            searchEngine.index(newFiles ?? [])
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            let count = searchResults.count
            if selectedIndex < count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            isVisible = false
            return .handled
        }
    }

    private func openSelectedFile() {
        let results = searchResults
        guard selectedIndex < results.count else { return }
        openFile(results[selectedIndex].file)
    }

    private func openFile(_ file: WorkspaceFile) {
        NSDocumentController.shared.openDocument(
            withContentsOf: file.url,
            display: true
        ) { _, _, _ in }
        isVisible = false
    }
}

// MARK: - Document Statistics Bar (Phase 6)

struct DocumentStatisticsBar: View {
    let statistics: DocumentStatistics

    var body: some View {
        HStack(spacing: 16) {
            StatItem(label: "Words", value: "\(statistics.wordCount)")
            Divider().frame(height: 12)
            StatItem(label: "Characters", value: "\(statistics.characterCount)")
            Divider().frame(height: 12)
            StatItem(label: "Sentences", value: "\(statistics.sentenceCount)")
            Divider().frame(height: 12)
            StatItem(label: "Lines", value: "\(statistics.lineCount)")
            Divider().frame(height: 12)
            StatItem(label: "Read time", value: readingTimeText)
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor)),
            alignment: .top
        )
    }

    private var readingTimeText: String {
        let minutes = statistics.readingTimeMinutes
        if minutes < 1 {
            return "< 1 min"
        }
        return "~\(Int(ceil(minutes))) min"
    }
}

private struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundColor(.secondary)
            Text(value)
        }
    }
}

// MARK: - Settings View (Phase 4: Added Keybindings tab)

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
                .tag(0)

            ThemeSettingsView()
                .tabItem { Label("Themes", systemImage: "paintbrush") }
                .tag(1)

            EditorSettingsView()
                .tabItem { Label("Editor", systemImage: "doc.text") }
                .tag(2)

            KeybindingsSettingsView()
                .tabItem { Label("Keybindings", systemImage: "keyboard") }
                .tag(3)

            SyncSettingsView()
                .tabItem { Label("Sync", systemImage: "arrow.clockwise") }
                .tag(4)

            ExportSettingsView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
                .tag(5)

            AISettingsView(
                configuration: appState.aiConfiguration,
                privacyManager: appState.aiPrivacyManager
            )
            .tabItem { Label("AI", systemImage: "sparkles") }
            .tag(6)
        }
        .frame(width: 560, height: 500)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("showLineNumbers") private var showLineNumbers = false
    @AppStorage("showInvisibles") private var showInvisibles = false
    @AppStorage("checkSpelling") private var checkSpelling = true

    var body: some View {
        Form {
            Section {
                Toggle("Show line numbers", isOn: $showLineNumbers)
                Toggle("Show invisible characters", isOn: $showInvisibles)
                Toggle("Check spelling as you type", isOn: $checkSpelling)
            }
        }
        .padding()
    }
}

// MARK: - Theme Settings

struct ThemeSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(appState.themeManager.availableThemes, id: \.id) { theme in
            HStack {
                Text(theme.name)
                Spacer()
                if theme.id == appState.themeManager.currentTheme.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appState.themeManager.setTheme(theme)
            }
        }
    }
}

// MARK: - Editor Settings

struct EditorSettingsView: View {
    @AppStorage("tabWidth") private var tabWidth = 4
    @AppStorage("useSpacesForTabs") private var useSpacesForTabs = true
    @AppStorage("enableSmartPairs") private var enableSmartPairs = true
    @AppStorage("enableSmartLists") private var enableSmartLists = true
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Input") {
                Picker("Tab width", selection: $tabWidth) {
                    Text("2 spaces").tag(2)
                    Text("4 spaces").tag(4)
                    Text("8 spaces").tag(8)
                }

                Toggle("Use spaces for tabs", isOn: $useSpacesForTabs)
                Toggle("Enable smart pairs", isOn: $enableSmartPairs)
                Toggle("Enable smart lists", isOn: $enableSmartLists)
            }

            Section("Vim Mode") {
                Toggle("Enable Vim mode", isOn: $appState.vimModeHandler.isEnabled)
                if appState.vimModeHandler.isEnabled {
                    HStack {
                        Text("Current mode:")
                        Text(appState.vimModeHandler.mode.rawValue.capitalized)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Keybindings Settings (Phase 4: New)

struct KeybindingsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    var filteredCommands: [CommandDefinition] {
        appState.commandRegistry.search(query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search keybindings...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))

            Divider()

            // Keybinding list
            List(filteredCommands, id: \.id) { command in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(command.name)
                            .font(.system(size: 12))
                        Text(command.id)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let shortcut = appState.commandRegistry.shortcut(for: command.id) {
                        Text(KeyComboParser.displayString(for: shortcut))
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.separatorColor).opacity(0.3))
                            .cornerRadius(4)
                    } else {
                        Text("Not set")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 1)
            }
            .listStyle(.plain)

            Divider()

            // Footer with reset button
            HStack {
                Button("Reset to Defaults") {
                    appState.commandRegistry.resetAllShortcuts()
                }

                Spacer()

                Text("\(filteredCommands.count) commands")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
    }
}

// MARK: - Sync Settings

struct SyncSettingsView: View {
    @AppStorage("enableICloudSync") private var enableICloudSync = true
    @AppStorage("enableAutoSave") private var enableAutoSave = true
    @AppStorage("autoSaveInterval") private var autoSaveInterval = 2.0
    @AppStorage("followSystemAppearance") private var followSystemAppearance = false
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("iCloud") {
                Toggle("Enable iCloud sync", isOn: $enableICloudSync)

                HStack {
                    Text("Status:")
                    Image(systemName: appState.syncStatusTracker.status.systemImageName)
                    Text(appState.syncStatusTracker.status.description)
                        .foregroundColor(.secondary)
                }

                if let lastSync = appState.syncStatusTracker.lastSyncDescription {
                    HStack {
                        Text("Last synced:")
                        Text(lastSync)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Auto-Save") {
                Toggle("Auto-save", isOn: $enableAutoSave)

                if enableAutoSave {
                    HStack {
                        Text("Save interval:")
                        Slider(value: $autoSaveInterval, in: 1...10, step: 1)
                        Text("\(Int(autoSaveInterval))s")
                            .frame(width: 30)
                    }
                }
            }

            Section("Appearance") {
                Toggle("Follow system appearance", isOn: $followSystemAppearance)
            }
        }
        .padding()
    }
}

// MARK: - Export Settings

struct ExportSettingsView: View {
    @AppStorage("pdfPageSize") private var pdfPageSize = "letter"
    @AppStorage("exportIncludeMetadata") private var exportIncludeMetadata = true

    var body: some View {
        Form {
            Section("PDF") {
                Picker("Page size", selection: $pdfPageSize) {
                    Text("US Letter").tag("letter")
                    Text("A4").tag("a4")
                }
            }

            Section("General") {
                Toggle("Include metadata in exports", isOn: $exportIncludeMetadata)
            }
        }
        .padding()
    }
}

// MARK: - Commands

struct TymarkCommands: Commands {
    var appState: AppState
    @FocusedValue(\.exportAction) var exportAction

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Quick Open...") {
                appState.isQuickOpenVisible = true
            }
            .keyboardShortcut("p", modifiers: .command)
        }

        CommandMenu("View") {
            Button("Toggle Sidebar") {
                appState.isSidebarVisible.toggle()
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])

            Button("Command Palette") {
                appState.isCommandPaletteVisible.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Divider()

            Button("Toggle Focus Mode") {
                appState.isFocusModeEnabled.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Divider()

            Toggle("Vim Mode", isOn: Binding(
                get: { appState.vimModeHandler.isEnabled },
                set: { appState.vimModeHandler.isEnabled = $0 }
            ))
        }

        CommandMenu("Export") {
            Button("Export as HTML...") {
                exportAction?("html")
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(exportAction == nil)

            Button("Export as PDF...") {
                exportAction?("pdf")
            }
            .disabled(exportAction == nil)

            Button("Export as Word...") {
                exportAction?("docx")
            }
            .disabled(exportAction == nil)

            Button("Export as RTF...") {
                exportAction?("rtf")
            }
            .disabled(exportAction == nil)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App launched
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - UTType Extension

extension UTType {
    static var markdown: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}
