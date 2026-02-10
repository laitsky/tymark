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
            WorkspaceContentView(document: configuration.document, fileURL: configuration.fileURL)
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
    @Published var workspaceViewMode: WorkspaceViewMode = .split
    @Published var isInspectorVisible = true
    @Published var isTypewriterModeEnabled = UserDefaults.standard.bool(forKey: "enableTypewriterMode")

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

        if UserDefaults.standard.object(forKey: "enableICloudSync") == nil {
            UserDefaults.standard.set(true, forKey: "enableICloudSync")
        }
        if UserDefaults.standard.bool(forKey: "enableICloudSync") {
            cloudSyncManager.startMonitoring()
        }

        registerCommands()
        keybindingHandler.setCommandRegistry(commandRegistry)
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

            Button("Editor Only") {
                appState.workspaceViewMode = .editor
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Split Editor + Preview") {
                appState.workspaceViewMode = .split
            }
            .keyboardShortcut("2", modifiers: [.command, .option])

            Button("Preview Only") {
                appState.workspaceViewMode = .preview
            }
            .keyboardShortcut("3", modifiers: [.command, .option])

            Button("Toggle Inspector") {
                appState.isInspectorVisible.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

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
