import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WebKit
import TymarkParser
import TymarkEditor
import TymarkTheme
import TymarkWorkspace
import TymarkSync

// MARK: - Workspace Modes

enum WorkspaceViewMode: String, CaseIterable, Identifiable, Sendable {
    case editor
    case split
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editor:
            return "Editor"
        case .split:
            return "Split"
        case .preview:
            return "Preview"
        }
    }

    var systemImage: String {
        switch self {
        case .editor:
            return "square.and.pencil"
        case .split:
            return "rectangle.split.2x1"
        case .preview:
            return "doc.richtext"
        }
    }
}

// MARK: - Content View Revamp

struct WorkspaceContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var document: TymarkDocumentModel
    var fileURL: URL?

    @State private var selection = NSRange(location: 0, length: 0)
    @StateObject private var editorViewModel = EditorViewModel()
    @StateObject private var previewViewModel = MarkdownPreviewViewModel()

    @State private var outlineItems: [DocumentOutlineItem] = []
    @State private var lineStartOffsets: [Int] = [0]
    @State private var cursorLine = 1
    @State private var cursorColumn = 1
    @State private var selectedCharacterCount = 0
    @State private var previewScrollProgress = 0.0
    @State private var isApplyingPreviewDrivenSelection = false
    @State private var previewSyncTask: Task<Void, Never>?

    @State private var deriveTask: Task<Void, Never>?
    @State private var spotlightTask: Task<Void, Never>?
    @State private var pendingPreviewRefresh = true

    private var effectiveMode: WorkspaceViewMode {
        appState.isFocusModeEnabled ? .editor : appState.workspaceViewMode
    }

    private var showsInspector: Bool {
        !appState.isFocusModeEnabled && appState.isInspectorVisible
    }

    var body: some View {
        NavigationSplitView {
            if appState.isSidebarVisible {
                SidebarView()
                    .environmentObject(appState.workspaceManager)
            }
        } detail: {
            HSplitView {
                VStack(spacing: 0) {
                    if appState.isFindBarVisible,
                       let textView = appState.activeTextManipulator as? TymarkTextView {
                        FindReplaceBar(
                            engine: textView.findReplaceEngine,
                            isVisible: $appState.isFindBarVisible
                        )
                    }

                    DocumentTabStrip(
                        currentFileURL: fileURL,
                        recentFiles: appState.workspaceManager.currentWorkspace?.recentFiles ?? [],
                        onSelectFile: openDocumentInTab
                    )

                    workspaceHeader
                    workspaceBody

                    if appState.isStatisticsBarVisible {
                        DocumentStatisticsBar(statistics: appState.documentStatistics)
                    }
                }
                .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)

                if showsInspector {
                    Divider()
                    InspectorPane(
                        outlineItems: outlineItems,
                        metadata: document.metadata,
                        statistics: appState.documentStatistics,
                        onJump: jumpToOutline,
                        onReorder: reorderOutline
                    )
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 360, maxHeight: .infinity)
                    .background(Color(.controlBackgroundColor))
                }
            }

            if appState.aiAssistantState.isVisible {
                AIAssistantPanel(state: appState.aiAssistantState)
                    .environmentObject(appState)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { appState.isSidebarVisible.toggle() }) {
                    Image(systemName: appState.isSidebarVisible ? "sidebar.left" : "sidebar.left.fill")
                }
                .help("Toggle Sidebar")

                Button(action: { appState.openDocument() }) {
                    Image(systemName: "folder")
                }
                .help("Open Document")
            }

            ToolbarItemGroup(placement: .principal) {
                Picker("Workspace", selection: $appState.workspaceViewMode) {
                    ForEach(WorkspaceViewMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                .disabled(appState.isFocusModeEnabled)
            }

            ToolbarItemGroup(placement: .automatic) {
                SyncStatusView(tracker: appState.syncStatusTracker)

                Button(action: { appState.isInspectorVisible.toggle() }) {
                    Image(systemName: appState.isInspectorVisible ? "sidebar.right" : "sidebar.right.fill")
                }
                .help("Toggle Inspector")
                .disabled(appState.isFocusModeEnabled)

                Menu {
                    ForEach(appState.themeManager.availableThemes, id: \.id) { theme in
                        Button(theme.name) {
                            appState.themeManager.setTheme(theme)
                            editorViewModel.setTheme(theme)
                            previewViewModel.setTheme(theme)
                        }
                    }
                } label: {
                    Image(systemName: "paintbrush")
                }

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

                Menu {
                    Button("Insert Table") {
                        appState.activeTextManipulator?.insertAtCursor(
                            """
                            | Column 1 | Column 2 |
                            | --- | --- |
                            |  |  |
                            """
                        )
                    }
                    Button("Add Row Below") {
                        appState.activeTextManipulator?.addTableRowBelow()
                    }
                    Button("Add Column") {
                        appState.activeTextManipulator?.addTableColumnAfter()
                    }
                    Button("Cycle Column Alignment") {
                        appState.activeTextManipulator?.cycleTableColumnAlignment()
                    }
                } label: {
                    Image(systemName: "tablecells")
                }

                Button(action: { appState.isCommandPaletteVisible.toggle() }) {
                    Image(systemName: "command")
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
        .safeAreaInset(edge: .bottom) {
            WorkspaceStatusBar(
                mode: effectiveMode,
                line: cursorLine,
                column: cursorColumn,
                selectionLength: selectedCharacterCount,
                statistics: appState.documentStatistics,
                isSourceMode: editorViewModel.isSourceMode,
                isFocusMode: appState.isFocusModeEnabled,
                isTypewriterMode: appState.isTypewriterModeEnabled
            )
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
            let theme = appState.themeManager.currentTheme
            editorViewModel.setTheme(theme)
            previewViewModel.setTheme(theme)

            appState.aiAssistantState.onAcceptResponse = { [weak appState] text in
                appState?.activeTextManipulator?.insertAtCursor(text)
            }

            refreshDerivedData(for: document.content)
            schedulePreviewRender(for: document.content)
            scheduleSpotlightIndexing(for: document.content)
            updateCursorPosition(for: selection)
        }
        .onDisappear {
            deriveTask?.cancel()
            spotlightTask?.cancel()
            previewSyncTask?.cancel()
            previewViewModel.cancelPendingRender()
        }
        .onChange(of: document.content) { _, newValue in
            refreshDerivedData(for: newValue)
            schedulePreviewRender(for: newValue)
            scheduleSpotlightIndexing(for: newValue)
        }
        .onChange(of: appState.workspaceViewMode) { _, _ in
            schedulePreviewRender(for: document.content)
        }
        .onChange(of: appState.isFocusModeEnabled) { _, _ in
            schedulePreviewRender(for: document.content)
        }
        .onChange(of: selection) { _, newValue in
            updateCursorPosition(for: newValue)
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
        .onChange(of: appState.themeManager.currentTheme) { _, newTheme in
            editorViewModel.setTheme(newTheme)
            previewViewModel.setTheme(newTheme)
            pendingPreviewRefresh = true
            schedulePreviewRender(for: document.content)
        }
    }

    @ViewBuilder
    private var workspaceBody: some View {
        switch effectiveMode {
        case .editor:
            editorPaneWithMinimap
        case .preview:
            previewPane
        case .split:
            HSplitView {
                editorPaneWithMinimap
                    .frame(minWidth: 360, maxWidth: .infinity)
                Divider()
                previewPane
                    .frame(minWidth: 320, maxWidth: .infinity)
            }
        }
    }

    private var editorPaneWithMinimap: some View {
        HStack(spacing: 0) {
            editorPane

            MinimapView(
                lineCount: max(1, appState.documentStatistics.lineCount),
                currentLine: cursorLine,
                outlineItems: outlineItems,
                onSelectProgress: { progress in
                    jumpToProgress(progress)
                }
            )
            .frame(width: 54)
            .background(Color(.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(Color(.separatorColor)),
                alignment: .leading
            )
        }
    }

    private var editorPane: some View {
        ZStack(alignment: .bottom) {
            TymarkEditorView(
                text: $document.content,
                selection: $selection,
                viewModel: editorViewModel,
                keybindingHandler: appState.keybindingHandler,
                vimModeHandler: appState.vimModeHandler,
                isTypewriterModeEnabled: appState.isTypewriterModeEnabled,
                onTextManipulatorReady: { manipulator in
                    appState.activeTextManipulator = manipulator
                    if let tv = manipulator as? TymarkTextView {
                        tv.findReplaceEngine.attach(to: tv)
                    }
                },
                documentURL: fileURL
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if appState.vimModeHandler.isEnabled {
                VimStatusBar(handler: appState.vimModeHandler)
            }
        }
    }

    private var previewPane: some View {
        ZStack(alignment: .topTrailing) {
            MarkdownPreviewView(
                html: previewViewModel.html,
                baseURL: fileURL?.deletingLastPathComponent(),
                scrollProgress: previewScrollProgress,
                onUserScroll: handlePreviewUserScroll
            )
            .background(Color(.textBackgroundColor))

            if previewViewModel.isRendering {
                ProgressView()
                    .controlSize(.small)
                    .padding(10)
            }
        }
    }

    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(document.metadata.title ?? "Untitled")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)

                Text(fileURL?.path(percentEncoded: false) ?? "Unsaved document")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 10) {
                Label("\(appState.documentStatistics.wordCount)", systemImage: "text.word.spacing")
                Label(readingTimeText, systemImage: "clock")
                Label("\(outlineItems.count)", systemImage: "list.bullet.indent")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor)),
            alignment: .bottom
        )
    }

    private var readingTimeText: String {
        let minutes = appState.documentStatistics.readingTimeMinutes
        if minutes < 1 {
            return "< 1 min"
        }
        return "\(Int(ceil(minutes))) min"
    }

    private func schedulePreviewRender(for content: String) {
        guard effectiveMode != .editor else {
            pendingPreviewRefresh = true
            return
        }
        guard pendingPreviewRefresh || !previewViewModel.matches(markdown: content, title: document.metadata.title) else {
            return
        }
        previewViewModel.scheduleRender(markdown: content, title: document.metadata.title)
        pendingPreviewRefresh = false
    }

    private func refreshDerivedData(for content: String) {
        deriveTask?.cancel()

        let snapshot = content
        deriveTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }

            let computeTask = Task.detached(priority: .userInitiated) {
                DerivedDocumentData.compute(from: snapshot)
            }
            let derived = await withTaskCancellationHandler {
                await computeTask.value
            } onCancel: {
                computeTask.cancel()
            }

            guard !Task.isCancelled else { return }
            outlineItems = derived.outline
            lineStartOffsets = derived.lineStarts
            appState.documentStatistics = derived.statistics
            updateCursorPosition(for: selection)
        }
    }

    private func scheduleSpotlightIndexing(for content: String) {
        guard let fileURL else { return }
        let snapshot = content
        let title = document.metadata.title

        spotlightTask?.cancel()
        spotlightTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            appState.spotlightIndexer.indexDocument(at: fileURL, content: snapshot, title: title)
        }
    }

    private func updateCursorPosition(for range: NSRange) {
        selectedCharacterCount = max(0, range.length)

        let contentLength = (document.content as NSString).length
        let location = min(max(0, range.location), contentLength)
        if !isApplyingPreviewDrivenSelection {
            previewScrollProgress = contentLength > 1
                ? Double(location) / Double(contentLength - 1)
                : 0
        }

        guard !lineStartOffsets.isEmpty else {
            cursorLine = 1
            cursorColumn = location + 1
            return
        }

        let lineIndex = lineIndexForLocation(location)
        let lineStart = lineStartOffsets[lineIndex]

        cursorLine = lineIndex + 1
        cursorColumn = location - lineStart + 1
    }

    private func lineIndexForLocation(_ location: Int) -> Int {
        var low = 0
        var high = lineStartOffsets.count

        while low < high {
            let mid = (low + high) / 2
            if lineStartOffsets[mid] <= location {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return max(0, min(lineStartOffsets.count - 1, low - 1))
    }

    private func jumpToOutline(_ item: DocumentOutlineItem) {
        let range = NSRange(location: item.location, length: 0)
        selection = range

        guard let textView = appState.activeTextManipulator as? TymarkTextView else { return }
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.window?.makeFirstResponder(textView)
    }

    private func jumpToProgress(_ progress: Double, focusEditor: Bool = true) {
        let clamped = min(max(progress, 0), 1)
        let contentLength = (document.content as NSString).length
        let location = Int((Double(max(0, contentLength - 1)) * clamped).rounded(.towardZero))
        let range = NSRange(location: location, length: 0)

        selection = range

        guard let textView = appState.activeTextManipulator as? TymarkTextView else { return }
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        if focusEditor {
            textView.window?.makeFirstResponder(textView)
        }
    }

    private func handlePreviewUserScroll(_ progress: Double) {
        guard effectiveMode != .editor else { return }

        let clamped = min(max(progress, 0), 1)
        previewSyncTask?.cancel()
        previewSyncTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }
            guard abs(previewScrollProgress - clamped) > 0.003 else { return }

            isApplyingPreviewDrivenSelection = true
            previewScrollProgress = clamped
            jumpToProgress(clamped, focusEditor: false)
            isApplyingPreviewDrivenSelection = false
        }
    }

    private func reorderOutline(fromOffsets: IndexSet, toOffset: Int) {
        guard let from = fromOffsets.first, from < outlineItems.count else { return }
        let contentLength = (document.content as NSString).length
        guard let movingRange = sectionRange(for: from, in: outlineItems, contentLength: contentLength) else { return }

        let movingLevel = outlineItems[from].level
        let subtreeEndIndex = nextSiblingIndex(after: from, level: movingLevel, in: outlineItems) ?? outlineItems.count
        if toOffset > from && toOffset <= subtreeEndIndex {
            return
        }

        let nsSource = document.content as NSString
        let movingText = nsSource.substring(with: movingRange)

        var reordered = outlineItems
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        guard let movedIndex = reordered.firstIndex(where: { $0.id == outlineItems[from].id }) else { return }

        let insertionLocationOriginal: Int
        if movedIndex == 0 {
            insertionLocationOriginal = 0
        } else {
            let previous = reordered[movedIndex - 1]
            guard let previousIndex = outlineItems.firstIndex(where: { $0.id == previous.id }),
                  let previousRange = sectionRange(for: previousIndex, in: outlineItems, contentLength: contentLength) else { return }
            insertionLocationOriginal = NSMaxRange(previousRange)
        }

        let adjustedInsertion: Int = {
            if insertionLocationOriginal > movingRange.location {
                return max(0, insertionLocationOriginal - movingRange.length)
            }
            return insertionLocationOriginal
        }()

        let mutable = NSMutableString(string: document.content)
        mutable.replaceCharacters(in: movingRange, with: "")
        mutable.insert(movingText, at: min(adjustedInsertion, mutable.length))
        document.content = String(mutable)
    }

    private func sectionRange(
        for index: Int,
        in items: [DocumentOutlineItem],
        contentLength: Int
    ) -> NSRange? {
        guard index >= 0, index < items.count else { return nil }
        let start = items[index].location
        let level = items[index].level
        let end = nextSiblingIndex(after: index, level: level, in: items).map { items[$0].location } ?? contentLength
        guard end >= start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private func nextSiblingIndex(after index: Int, level: Int, in items: [DocumentOutlineItem]) -> Int? {
        guard index + 1 < items.count else { return nil }
        for candidate in (index + 1)..<items.count where items[candidate].level <= level {
            return candidate
        }
        return nil
    }

    private func openDocumentInTab(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            guard let error else { return }
            Task { @MainActor in
                _ = NSApp.presentError(error)
            }
        }
    }

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

// MARK: - Status Bar

private struct DocumentTabStrip: View {
    let currentFileURL: URL?
    let recentFiles: [URL]
    let onSelectFile: (URL) -> Void
    @State private var hoveredURL: URL?

    private var tabs: [URL] {
        var ordered: [URL] = []
        if let currentFileURL {
            ordered.append(currentFileURL)
        }
        for url in recentFiles where !ordered.contains(url) {
            ordered.append(url)
        }
        return Array(ordered.prefix(10))
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if tabs.isEmpty {
                    Label("Unsaved", systemImage: "doc")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.controlBackgroundColor).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    ForEach(tabs, id: \.self) { url in
                        Button {
                            onSelectFile(url)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                if currentFileURL == url {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(backgroundColor(for: url))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(borderColor(for: url), lineWidth: currentFileURL == url ? 1 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .help(url.path(percentEncoded: false))
                        .onHover { isHovered in
                            hoveredURL = isHovered ? url : (hoveredURL == url ? nil : hoveredURL)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor)),
            alignment: .bottom
        )
    }

    private func backgroundColor(for url: URL) -> Color {
        if currentFileURL == url {
            return Color.accentColor.opacity(0.22)
        }
        if hoveredURL == url {
            return Color(.controlBackgroundColor).opacity(0.95)
        }
        return Color(.controlBackgroundColor).opacity(0.65)
    }

    private func borderColor(for url: URL) -> Color {
        if currentFileURL == url {
            return Color.accentColor.opacity(0.55)
        }
        return Color(.separatorColor).opacity(0.45)
    }
}

private struct MinimapView: View {
    let lineCount: Int
    let currentLine: Int
    let outlineItems: [DocumentOutlineItem]
    let onSelectProgress: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.controlBackgroundColor),
                                Color(.windowBackgroundColor).opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)

                Canvas { context, size in
                    let height = max(1, size.height)
                    let width = max(1, size.width)

                    // Base texture
                    let baseStride = max(2, lineCount / Int(height / 1.6))
                    for index in stride(from: 1, through: lineCount, by: baseStride) {
                        let progress = CGFloat(index - 1) / CGFloat(max(1, lineCount - 1))
                        let y = progress * height
                        let rect = CGRect(x: 10, y: y, width: width - 20, height: 1)
                        context.fill(Path(rect), with: .color(Color.secondary.opacity(0.25)))
                    }

                    // Heading markers
                    for item in outlineItems {
                        let progress = CGFloat(item.lineNumber - 1) / CGFloat(max(1, lineCount - 1))
                        let y = progress * height
                        let markerWidth = max(4, (width - 20) * (1.1 - CGFloat(min(item.level, 6)) * 0.13))
                        let rect = CGRect(x: width - markerWidth - 8, y: y, width: markerWidth, height: 2)
                        context.fill(Path(rect), with: .color(headingColor(for: item.level)))
                    }
                }
                .padding(.vertical, 8)

                let currentProgress = CGFloat(max(1, min(lineCount, currentLine)) - 1) / CGFloat(max(1, lineCount - 1))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.accentColor.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
                    )
                    .frame(width: max(8, geometry.size.width - 10), height: 12)
                    .offset(y: currentProgress * max(0, geometry.size.height - 12))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = Double(value.location.y / max(1, geometry.size.height))
                        onSelectProgress(progress)
                    }
            )
            .overlay(alignment: .top) {
                Text("MAP")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 3)
            }
        }
    }

    private func headingColor(for level: Int) -> Color {
        switch level {
        case 1: return Color.accentColor
        case 2: return Color.accentColor.opacity(0.86)
        case 3: return Color.accentColor.opacity(0.74)
        case 4: return Color.accentColor.opacity(0.62)
        case 5: return Color.accentColor.opacity(0.5)
        default: return Color.accentColor.opacity(0.4)
        }
    }
}

private struct WorkspaceStatusBar: View {
    let mode: WorkspaceViewMode
    let line: Int
    let column: Int
    let selectionLength: Int
    let statistics: DocumentStatistics
    let isSourceMode: Bool
    let isFocusMode: Bool
    let isTypewriterMode: Bool

    var body: some View {
        HStack(spacing: 12) {
            statusPill(icon: "rectangle.split.2x1", text: mode.title)
            statusPill(icon: "location", text: "Ln \(line), Col \(column)")
            statusPill(icon: "character.cursor.ibeam", text: "Sel \(selectionLength)")
            statusPill(icon: "text.alignleft", text: "Chars \(statistics.characterCount)")

            Spacer()

            if isSourceMode {
                statusPill(icon: "curlybraces", text: "Source")
            }
            if isFocusMode {
                statusPill(icon: "viewfinder", text: "Focus")
            }
            if isTypewriterMode {
                statusPill(icon: "text.aligncenter", text: "Typewriter")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .font(.system(size: 11, weight: .medium))
        .background(Color(.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor)),
            alignment: .top
        )
    }

    private func statusPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Inspector

private struct InspectorPane: View {
    let outlineItems: [DocumentOutlineItem]
    let metadata: DocumentMetadata
    let statistics: DocumentStatistics
    let onJump: (DocumentOutlineItem) -> Void
    let onReorder: (IndexSet, Int) -> Void
    @State private var outlineSearch = ""

    private var filteredOutlineItems: [DocumentOutlineItem] {
        let query = outlineSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return outlineItems }
        return outlineItems.filter { item in
            item.title.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Document") {
                    VStack(alignment: .leading, spacing: 8) {
                        metadataRow("Title", metadata.title ?? "Untitled")
                        metadataRow("Words", "\(statistics.wordCount)")
                        metadataRow("Chars", "\(statistics.characterCount)")
                        metadataRow("Updated", metadata.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Outline") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Search headings", text: $outlineSearch)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .padding(.bottom, 4)

                        HStack {
                            Text("\(filteredOutlineItems.count) items")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            if outlineSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Drag to reorder")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 2)

                        if filteredOutlineItems.isEmpty {
                            Text(outlineSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No headings yet" : "No matching headings")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            if outlineSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                List {
                                    ForEach(outlineItems) { item in
                                        outlineRow(item)
                                    }
                                    .onMove(perform: onReorder)
                                }
                                .listStyle(.plain)
                                .frame(minHeight: 180, idealHeight: 240)
                            } else {
                                ForEach(filteredOutlineItems) { item in
                                    outlineRow(item)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
        }
        .font(.caption)
    }

    private func outlineRow(_ item: DocumentOutlineItem) -> some View {
        Button {
            onJump(item)
        } label: {
            HStack(spacing: 6) {
                Text("H\(item.level)")
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
                Text(item.title)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(max(0, item.level - 1)) * 10)
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Rendering

@MainActor
private final class MarkdownPreviewViewModel: ObservableObject {
    @Published var html: String = ""
    @Published var isRendering = false

    private var style = MarkdownPreviewProvider.PreviewStyle()
    private var renderTask: Task<Void, Never>?
    private var lastSignature: Int?

    func setTheme(_ theme: Theme) {
        style = MarkdownPreviewProvider.PreviewStyle(
            fontFamily: "\(theme.fonts.body.family), -apple-system, sans-serif",
            codeFontFamily: "\(theme.fonts.code.family), 'SF Mono', Menlo, monospace",
            fontSize: theme.fonts.body.size,
            textColor: theme.colors.text.hexString,
            backgroundColor: theme.colors.background.hexString,
            linkColor: theme.colors.link.hexString,
            codeBackgroundColor: theme.colors.codeBackground.hexString,
            quoteBorderColor: theme.colors.quoteBorder.hexString,
            maxWidth: 920
        )
        lastSignature = nil
    }

    func scheduleRender(markdown: String, title: String?) {
        let signature = Self.signature(for: markdown, title: title)
        guard signature != lastSignature else { return }

        renderTask?.cancel()
        isRendering = true

        let currentStyle = style
        renderTask = Task {
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }

            let computeTask = Task.detached(priority: .utility) {
                MarkdownPreviewProvider(style: currentStyle).generateHTMLPreview(from: markdown, title: title)
            }
            let rendered = await withTaskCancellationHandler {
                await computeTask.value
            } onCancel: {
                computeTask.cancel()
            }

            guard !Task.isCancelled else { return }
            html = rendered
            lastSignature = signature
            isRendering = false
        }
    }

    func cancelPendingRender() {
        renderTask?.cancel()
        isRendering = false
    }

    func matches(markdown: String, title: String?) -> Bool {
        Self.signature(for: markdown, title: title) == lastSignature
    }

    private static func signature(for markdown: String, title: String?) -> Int {
        var hasher = Hasher()
        hasher.combine(markdown)
        hasher.combine(title ?? "")
        return hasher.finalize()
    }
}

private struct MarkdownPreviewView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    let scrollProgress: Double
    let onUserScroll: (Double) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = false
        config.userContentController.add(context.coordinator, name: Coordinator.messageHandlerName)

        let scrollScript = WKUserScript(
            source: """
            (function() {
              if (window.__tymarkScrollSyncInstalled) { return; }
              window.__tymarkScrollSyncInstalled = true;
              var lastSent = -1;
              function emit() {
                const doc = document.documentElement || document.body;
                const maxScroll = Math.max(0, (doc.scrollHeight || 0) - window.innerHeight);
                const progress = maxScroll > 0 ? (window.scrollY / maxScroll) : 0;
                if (Math.abs(progress - lastSent) > 0.003) {
                  lastSent = progress;
                  window.webkit.messageHandlers.\(Coordinator.messageHandlerName).postMessage(progress);
                }
              }
              window.addEventListener('scroll', function() {
                if (window.__tymarkRafPending) { return; }
                window.__tymarkRafPending = true;
                requestAnimationFrame(function() {
                  emit();
                  window.__tymarkRafPending = false;
                });
              }, { passive: true });
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(scrollScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = true
        webView.magnification = 1.0
        webView.loadHTMLString(html, baseURL: baseURL)
        context.coordinator.lastHTML = html
        context.coordinator.pendingProgress = scrollProgress
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            context.coordinator.pendingProgress = scrollProgress
            nsView.loadHTMLString(html, baseURL: baseURL)
            return
        }

        if abs(context.coordinator.lastAppliedProgress - scrollProgress) > 0.01 {
            context.coordinator.applyScroll(progress: scrollProgress, to: nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onUserScroll: onUserScroll)
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.navigationDelegate = nil
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.messageHandlerName)
        nsView.configuration.userContentController.removeAllUserScripts()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        static let messageHandlerName = "tymarkPreviewScroll"

        private let onUserScroll: (Double) -> Void
        var lastHTML = ""
        var pendingProgress = 0.0
        var lastAppliedProgress = -1.0
        private var suppressCallbackUntil: TimeInterval = 0

        init(onUserScroll: @escaping (Double) -> Void) {
            self.onUserScroll = onUserScroll
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applyScroll(progress: pendingProgress, to: webView)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Self.messageHandlerName else { return }
            guard Date().timeIntervalSinceReferenceDate >= suppressCallbackUntil else { return }
            let raw: Double
            if let value = message.body as? NSNumber {
                raw = value.doubleValue
            } else if let value = message.body as? Double {
                raw = value
            } else {
                return
            }
            let clamped = min(max(raw, 0), 1)
            onUserScroll(clamped)
        }

        func applyScroll(progress: Double, to webView: WKWebView) {
            let clamped = min(max(progress, 0), 1)
            lastAppliedProgress = clamped
            suppressCallbackUntil = Date().timeIntervalSinceReferenceDate + 0.18
            let script = """
            (function() {
              var doc = document.documentElement || document.body;
              var maxScroll = Math.max(0, (doc.scrollHeight || 0) - window.innerHeight);
              window.scrollTo(0, maxScroll * \(clamped));
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
}

// MARK: - Derived Document Data

private struct DocumentOutlineItem: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let level: Int
    let lineNumber: Int
    let location: Int
    let length: Int
}

private struct DerivedDocumentData: Sendable {
    let statistics: DocumentStatistics
    let outline: [DocumentOutlineItem]
    let lineStarts: [Int]

    static func compute(from source: String) -> DerivedDocumentData {
        let stats = DocumentStatisticsEngine.compute(from: source)
        let lineStarts = computeLineStarts(in: source)
        let outline = computeOutline(from: source, lineStarts: lineStarts)
        return DerivedDocumentData(statistics: stats, outline: outline, lineStarts: lineStarts)
    }

    private static func computeLineStarts(in source: String) -> [Int] {
        let nsSource = source as NSString
        guard nsSource.length > 0 else { return [0] }

        var starts = [0]
        starts.reserveCapacity(max(8, nsSource.length / 32))

        for index in 0..<nsSource.length where nsSource.character(at: index) == 0x0A {
            starts.append(index + 1)
        }

        return starts
    }

    private static func computeOutline(from source: String, lineStarts: [Int]) -> [DocumentOutlineItem] {
        let lines = source.components(separatedBy: "\n")
        var items: [DocumentOutlineItem] = []
        items.reserveCapacity(16)

        for (lineNumber, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { continue }

            let level = trimmed.prefix { $0 == "#" }.count
            guard level >= 1 && level <= 6 else { continue }

            let titlePart = trimmed.dropFirst(level)
            let title = titlePart.hasPrefix(" ")
                ? String(titlePart.dropFirst())
                : String(titlePart)

            guard !title.isEmpty else { continue }

            let location = lineNumber < lineStarts.count ? lineStarts[lineNumber] : 0
            let length = (line as NSString).length

            items.append(DocumentOutlineItem(
                id: location,
                title: title,
                level: level,
                lineNumber: lineNumber + 1,
                location: location,
                length: length
            ))
        }

        return items
    }
}
