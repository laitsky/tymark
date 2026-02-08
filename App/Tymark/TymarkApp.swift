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

    let spotlightIndexer = SpotlightIndexer()
    let exportManager = ExportManager()
    lazy var cloudSyncManager: TymarkSync.iCloudSyncManager = {
        TymarkSync.iCloudSyncManager(syncStatusTracker: syncStatusTracker, networkMonitor: networkMonitor)
    }()
    let versionManager = DocumentVersionManager()

    init() {
        networkMonitor.start()
        syncStatusTracker.configure(with: networkMonitor)
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
            TymarkEditorView(
                text: $document.content,
                selection: $selection,
                viewModel: editorViewModel
            )
            .frame(minWidth: 400, minHeight: 300)
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
            CommandPaletteView(isVisible: $appState.isCommandPaletteVisible)
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

// MARK: - Command Palette View

struct CommandPaletteView: View {
    @Binding var isVisible: Bool
    @State private var searchText = ""

    let commands: [(name: String, shortcut: String, action: () -> Void)] = [
        ("New Document", "Cmd+N", {}),
        ("Open Document", "Cmd+O", {}),
        ("Save", "Cmd+S", {}),
        ("Quick Open", "Cmd+P", {}),
        ("Toggle Sidebar", "Cmd+Shift+B", {}),
        ("Toggle Focus Mode", "Cmd+Shift+F", {}),
        ("Export to HTML", "Cmd+Shift+E", {}),
        ("Export to PDF", "Cmd+Shift+P", {}),
        ("Export to Word", "Cmd+Shift+W", {}),
        ("Toggle Source Mode", "Cmd+/", {}),
        ("Insert Link", "Cmd+K", {}),
        ("Bold", "Cmd+B", {}),
        ("Italic", "Cmd+I", {}),
    ]

    var filteredCommands: [(name: String, shortcut: String, action: () -> Void)] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search commands...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            List(filteredCommands, id: \.name) { command in
                HStack {
                    Text(command.name)
                    Spacer()
                    Text(command.shortcut)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    command.action()
                    isVisible = false
                }
            }
        }
        .frame(width: 500, height: 400)
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

// MARK: - Settings View

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

            SyncSettingsView()
                .tabItem { Label("Sync", systemImage: "arrow.clockwise") }
                .tag(3)

            ExportSettingsView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
                .tag(4)
        }
        .frame(width: 500, height: 400)
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

    var body: some View {
        Form {
            Section {
                Picker("Tab width", selection: $tabWidth) {
                    Text("2 spaces").tag(2)
                    Text("4 spaces").tag(4)
                    Text("8 spaces").tag(8)
                }

                Toggle("Use spaces for tabs", isOn: $useSpacesForTabs)
                Toggle("Enable smart pairs", isOn: $enableSmartPairs)
                Toggle("Enable smart lists", isOn: $enableSmartLists)
            }
        }
        .padding()
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
