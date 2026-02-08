import SwiftUI
import UniformTypeIdentifiers
import TymarkParser
import TymarkEditor
import TymarkTheme
import TymarkWorkspace
import TymarkSync

// MARK: - Tymark App

@main
struct TymarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appState = AppState()

    var body: some Scene {
        DocumentGroup(newDocument: TymarkDocumentModel()) {
            ContentView(document: $0.$document)
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
    @Published var isSidebarVisible = true
    @Published var isCommandPaletteVisible = false
    @Published var isQuickOpenVisible = false
}

// MARK: - Document Model

struct TymarkDocumentModel: FileDocument {
    var content: String {
        didSet {
            updateMetadata()
        }
    }
    var metadata: TymarkSync.TymarkDocument.DocumentMetadata

    init(content: String = "") {
        self.content = content
        self.metadata = TymarkSync.TymarkDocument.DocumentMetadata()
        updateMetadata()
    }

    private mutating func updateMetadata() {
        metadata.modifiedAt = Date()
        metadata.characterCount = (content as NSString).length
        metadata.wordCount = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    static var readableContentTypes: [UTType] {
        [.plainText, .markdown]
    }

    static var writableContentTypes: [UTType] {
        [.plainText, .markdown]
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = string
        self.metadata = TymarkSync.TymarkDocument.DocumentMetadata()
        updateMetadata()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Binding var document: TymarkDocumentModel

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

                    Button(action: { appState.isCommandPaletteVisible = true }) {
                        Image(systemName: "command")
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                }
            }
        }
        .sheet(isPresented: $appState.isCommandPaletteVisible) {
            CommandPaletteView(isVisible: $appState.isCommandPaletteVisible)
        }
        .sheet(isPresented: $appState.isQuickOpenVisible) {
            QuickOpenView(isVisible: $appState.isQuickOpenVisible)
                .environmentObject(appState.workspaceManager)
        }
        .onAppear {
            editorViewModel.setTheme(appState.themeManager.currentTheme)
        }
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

            // Results would go here
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

    var body: some View {
        Form {
            Section {
                Toggle("Enable iCloud sync", isOn: $enableICloudSync)
                Toggle("Auto-save", isOn: $enableAutoSave)
            }
        }
        .padding()
    }
}

// MARK: - Commands

struct TymarkCommands: Commands {
    var appState: AppState

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
