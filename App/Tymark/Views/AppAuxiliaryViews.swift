import SwiftUI
import AppKit
import TymarkEditor
import TymarkTheme
import TymarkWorkspace
import TymarkSync

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
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            if let workspace = workspaceManager.currentWorkspace {
                Section(header: Text(workspace.name)) {
                    FileTreeView(files: workspace.openFiles)
                }
            }

            Section(header: Text("Favorites")) {
                if appState.favoriteDocumentURLs.isEmpty {
                    Text("No favorites yet")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(appState.favoriteDocumentURLs, id: \.self) { url in
                        Button {
                            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .help(url.path(percentEncoded: false))
                    }
                }
            }

            Section(header: Text("Recent")) {
                ForEach(workspaceManager.currentWorkspace?.recentFiles ?? [], id: \.self) { url in
                    Button {
                        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
                    } label: {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
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
                if let workspaceID = workspaceManager.currentWorkspace?.id {
                    workspaceManager.expandDirectory(file.id, in: workspaceID)
                }
            } else {
                workspaceManager.selectFile(file)
                workspaceManager.openFile(file)
                NSDocumentController.shared.openDocument(withContentsOf: file.url, display: true) { _, _, _ in }
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
    @AppStorage("enableTypewriterMode") private var enableTypewriterMode = false
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
                Toggle("Enable typewriter scrolling", isOn: $enableTypewriterMode)
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
        .onAppear {
            appState.isTypewriterModeEnabled = enableTypewriterMode
        }
        .onChange(of: enableTypewriterMode) { _, newValue in
            appState.isTypewriterModeEnabled = newValue
        }
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
        .onChange(of: enableICloudSync) { _, enabled in
            if enabled {
                appState.cloudSyncManager.startMonitoring()
            } else {
                appState.cloudSyncManager.stopMonitoring()
            }
        }
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
