import SwiftUI
import UniformTypeIdentifiers
import TymarkParser
import TymarkEditor
import TymarkTheme
import TymarkWorkspace
import TymarkSync
import TymarkExport

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
    @Published var isFocusModeEnabled = false

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
            ) { /* Handled by system */ },

            CommandDefinition(
                id: "file.open",
                name: "Open Document",
                category: .file,
                defaultShortcut: "cmd+o"
            ) { /* Handled by system */ },

            CommandDefinition(
                id: "file.save",
                name: "Save",
                category: .file,
                defaultShortcut: "cmd+s"
            ) { /* Handled by system */ },

            CommandDefinition(
                id: "file.saveAs",
                name: "Save As...",
                category: .file,
                defaultShortcut: "cmd+shift+s"
            ) { /* Handled by system */ },

            CommandDefinition(
                id: "file.close",
                name: "Close",
                category: .file,
                defaultShortcut: "cmd+w"
            ) { /* Handled by system */ },

            // Edit commands
            CommandDefinition(
                id: "edit.undo",
                name: "Undo",
                category: .edit,
                defaultShortcut: "cmd+z"
            ) { /* Handled by system responder chain */ },

            CommandDefinition(
                id: "edit.redo",
                name: "Redo",
                category: .edit,
                defaultShortcut: "cmd+shift+z"
            ) { /* Handled by system responder chain */ },

            CommandDefinition(
                id: "edit.cut",
                name: "Cut",
                category: .edit,
                defaultShortcut: "cmd+x"
            ) { /* Handled by system responder chain */ },

            CommandDefinition(
                id: "edit.copy",
                name: "Copy",
                category: .edit,
                defaultShortcut: "cmd+c"
            ) { /* Handled by system responder chain */ },

            CommandDefinition(
                id: "edit.paste",
                name: "Paste",
                category: .edit,
                defaultShortcut: "cmd+v"
            ) { /* Handled by system responder chain */ },

            CommandDefinition(
                id: "edit.selectAll",
                name: "Select All",
                category: .edit,
                defaultShortcut: "cmd+a"
            ) { /* Handled by system responder chain */ },

            // View commands
            CommandDefinition(
                id: "view.commandPalette",
                name: "Command Palette",
                category: .view,
                defaultShortcut: "cmd+shift+p"
            ) { [weak self] in
                self?.isCommandPaletteVisible = true
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
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "view.zoomIn",
                name: "Zoom In",
                category: .view,
                defaultShortcut: "cmd+="
            ) { /* Zoom handled by editor */ },

            CommandDefinition(
                id: "view.zoomOut",
                name: "Zoom Out",
                category: .view,
                defaultShortcut: "cmd+-"
            ) { /* Zoom handled by editor */ },

            CommandDefinition(
                id: "view.resetZoom",
                name: "Reset Zoom",
                category: .view,
                defaultShortcut: "cmd+0"
            ) { /* Zoom handled by editor */ },

            // Format commands
            CommandDefinition(
                id: "format.bold",
                name: "Bold",
                category: .format,
                defaultShortcut: "cmd+b"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.italic",
                name: "Italic",
                category: .format,
                defaultShortcut: "cmd+i"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.strikethrough",
                name: "Strikethrough",
                category: .format,
                defaultShortcut: "cmd+shift+x"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.inlineCode",
                name: "Inline Code",
                category: .format,
                defaultShortcut: "cmd+e"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.link",
                name: "Insert Link",
                category: .format,
                defaultShortcut: "cmd+k"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.heading1",
                name: "Heading 1",
                category: .format,
                defaultShortcut: "cmd+1"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.heading2",
                name: "Heading 2",
                category: .format,
                defaultShortcut: "cmd+2"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.heading3",
                name: "Heading 3",
                category: .format,
                defaultShortcut: "cmd+3"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.heading4",
                name: "Heading 4",
                category: .format,
                defaultShortcut: "cmd+4"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.heading5",
                name: "Heading 5",
                category: .format,
                defaultShortcut: "cmd+5"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.heading6",
                name: "Heading 6",
                category: .format,
                defaultShortcut: "cmd+6"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.orderedList",
                name: "Ordered List",
                category: .format,
                defaultShortcut: "cmd+shift+7"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.unorderedList",
                name: "Unordered List",
                category: .format,
                defaultShortcut: "cmd+shift+8"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.taskList",
                name: "Task List",
                category: .format,
                defaultShortcut: "cmd+shift+9"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.blockquote",
                name: "Blockquote",
                category: .format,
                defaultShortcut: "cmd+shift+."
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.codeBlock",
                name: "Code Block",
                category: .format,
                defaultShortcut: "cmd+shift+c"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "format.horizontalRule",
                name: "Horizontal Rule",
                category: .format,
                defaultShortcut: "cmd+shift+-"
            ) { /* Dispatched to editor */ },

            // Navigate commands
            CommandDefinition(
                id: "navigate.moveLineUp",
                name: "Move Line Up",
                category: .navigate,
                defaultShortcut: "alt+up"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "navigate.moveLineDown",
                name: "Move Line Down",
                category: .navigate,
                defaultShortcut: "alt+down"
            ) { /* Dispatched to editor */ },

            CommandDefinition(
                id: "navigate.duplicateLine",
                name: "Duplicate Line",
                category: .navigate,
                defaultShortcut: "cmd+shift+d"
            ) { /* Dispatched to editor */ },

            // Export commands
            CommandDefinition(
                id: "export.html",
                name: "Export as HTML",
                category: .export,
                defaultShortcut: "cmd+shift+e"
            ) { /* Handled via export action */ },

            CommandDefinition(
                id: "export.pdf",
                name: "Export as PDF",
                category: .export,
                defaultShortcut: "cmd+alt+p"
            ) { /* Handled via export action */ },

            CommandDefinition(
                id: "export.docx",
                name: "Export as Word",
                category: .export
            ) { /* Handled via export action */ },

            CommandDefinition(
                id: "export.rtf",
                name: "Export as RTF",
                category: .export
            ) { /* Handled via export action */ },

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
}

// MARK: - Document Model (ReferenceFileDocument)

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
        [.plainText, .markdown]
    }

    static var writableContentTypes: [UTType] {
        [.plainText, .markdown]
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
            ZStack(alignment: .bottom) {
                TymarkEditorView(
                    text: $document.content,
                    selection: $selection,
                    viewModel: editorViewModel
                )
                .frame(minWidth: 400, minHeight: 300)

                // Vim mode status bar
                if appState.vimModeHandler.isEnabled {
                    VimStatusBar(handler: appState.vimModeHandler)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                HStack {
                    Button(action: { appState.isSidebarVisible.toggle() }) {
                        Image(systemName: appState.isSidebarVisible ? "sidebar.left" : "sidebar.left.fill")
                    }

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

                    Button(action: { appState.isCommandPaletteVisible = true }) {
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
                    .onSubmit {
                        executeSelectedCommand()
                    }
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
                        isSelected: index == selectedIndex
                    )
                    .id(command.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        command.execute()
                        isVisible = false
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
        filteredCommands[selectedIndex].execute()
        isVisible = false
    }
}

// MARK: - Command Palette Row

struct CommandPaletteRow: View {
    let command: CommandDefinition
    let shortcut: String?
    let isSelected: Bool

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
    }
}

// MARK: - Quick Open View

struct QuickOpenView: View {
    @Binding var isVisible: Bool
    @EnvironmentObject var workspaceManager: WorkspaceManager
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search files...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            List {
                Text("Files matching '\(searchText)'")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 600, height: 400)
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
        }
        .frame(width: 560, height: 450)
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
                appState.isCommandPaletteVisible = true
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Divider()

            Button("Toggle Focus Mode") {
                appState.isFocusModeEnabled.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Divider()

            Toggle("Vim Mode", isOn: $appState.vimModeHandler.isEnabled)
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
