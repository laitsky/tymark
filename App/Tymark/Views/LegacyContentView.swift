import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TymarkParser
import TymarkEditor
import TymarkTheme
import TymarkWorkspace
import TymarkSync

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
            panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
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

