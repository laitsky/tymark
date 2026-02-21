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
    @State private var backlinks: [BacklinkHit] = []
    @State private var documentTags: [String] = []
    @State private var workspaceTagCounts: [TagCount] = []
    @State private var selectedTagFilter: String?
    @State private var taggedFiles: [URL] = []
    @State private var knowledgeIndex: WorkspaceKnowledgeIndex?

    @State private var deriveTask: Task<Void, Never>?
    @State private var spotlightTask: Task<Void, Never>?
    @State private var knowledgeTask: Task<Void, Never>?
    @State private var pendingPreviewRefresh = true

    private var effectiveMode: WorkspaceViewMode {
        appState.isFocusModeEnabled ? .editor : appState.workspaceViewMode
    }

    private var showsInspector: Bool {
        !appState.isFocusModeEnabled && appState.isInspectorVisible
    }

    private var workspaceFileCount: Int {
        appState.workspaceManager.currentWorkspace?.openFiles.count ?? 0
    }

    @ViewBuilder
    private var sidebarPane: some View {
        if appState.isSidebarVisible {
            SidebarView()
                .environmentObject(appState.workspaceManager)
                .environmentObject(appState)
        }
    }

    private var inspectorPaneView: some View {
        InspectorPane(
            outlineItems: outlineItems,
            metadata: document.metadata,
            statistics: appState.documentStatistics,
            backlinks: backlinks,
            documentTags: documentTags,
            workspaceTagCounts: workspaceTagCounts,
            selectedTag: selectedTagFilter,
            taggedFiles: taggedFiles,
            onJump: jumpToOutline,
            onReorder: reorderOutline,
            onOpenBacklink: openDocumentInTab,
            onSelectTag: { selectedTagFilter = $0 },
            onOpenTaggedFile: openDocumentInTab
        )
        .frame(minWidth: 240, idealWidth: 280, maxWidth: 360, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }

    var body: some View {
        NavigationSplitView {
            sidebarPane
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
                    inspectorPaneView
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
            scheduleKnowledgeIndexing(for: document.content)
            updateCursorPosition(for: selection)
        }
        .onDisappear {
            deriveTask?.cancel()
            spotlightTask?.cancel()
            previewSyncTask?.cancel()
            previewViewModel.cancelPendingRender()
            knowledgeTask?.cancel()
        }
        .onChange(of: document.content) { _, newValue in
            refreshDerivedData(for: newValue)
            schedulePreviewRender(for: newValue)
            scheduleSpotlightIndexing(for: newValue)
            scheduleKnowledgeIndexing(for: newValue)
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
        .onChange(of: workspaceFileCount) { _, _ in
            scheduleKnowledgeIndexing(for: document.content)
        }
        .onChange(of: fileURL) { _, _ in
            scheduleKnowledgeIndexing(for: document.content)
        }
        .onChange(of: selectedTagFilter) { _, newTag in
            guard let index = knowledgeIndex else {
                taggedFiles = []
                return
            }
            guard let newTag else {
                taggedFiles = []
                return
            }
            taggedFiles = filesForTag(newTag, from: index)
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

            Button {
                appState.toggleFavoriteDocument(fileURL)
            } label: {
                Image(systemName: appState.isFavoriteDocument(fileURL) ? "star.fill" : "star")
                    .foregroundColor(appState.isFavoriteDocument(fileURL) ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help(appState.isFavoriteDocument(fileURL) ? "Remove from favorites" : "Add to favorites")
            .disabled(fileURL == nil)

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

    private func scheduleKnowledgeIndexing(for content: String) {
        knowledgeTask?.cancel()

        let snapshot = content
        let currentURL = fileURL
        let workspaceFiles = appState.workspaceManager.currentWorkspace?.openFiles ?? []
        let selectedTag = selectedTagFilter

        knowledgeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            let documents = await Self.loadKnowledgeDocuments(
                from: workspaceFiles,
                currentFileURL: currentURL,
                currentContent: snapshot
            )

            let index = WorkspaceKnowledgeIndex.build(from: documents)
            knowledgeIndex = index
            workspaceTagCounts = index.tagCounts
            backlinks = currentURL.map { index.backlinks(for: $0) } ?? []

            if let currentURL {
                documentTags = index.tags(for: currentURL)
            } else {
                documentTags = MarkdownKnowledgeParser.extractTags(from: snapshot)
            }

            if let selectedTag, workspaceTagCounts.contains(where: { $0.tag == selectedTag }) {
                taggedFiles = filesForTag(selectedTag, from: index)
            } else {
                selectedTagFilter = nil
                taggedFiles = []
            }
        }
    }

    private func filesForTag(_ tag: String, from index: WorkspaceKnowledgeIndex) -> [URL] {
        index.files(matchingTag: tag).filter { candidate in
            guard let current = fileURL else { return true }
            return candidate != current
        }
    }

    private static func loadKnowledgeDocuments(
        from files: [WorkspaceFile],
        currentFileURL: URL?,
        currentContent: String
    ) async -> [URL: String] {
        let markdownURLs = collectMarkdownFileURLs(from: files)

        return await Task.detached(priority: .utility) {
            var documents: [URL: String] = [:]
            documents.reserveCapacity(markdownURLs.count + 1)

            for url in markdownURLs {
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
                documents[url.standardizedFileURL] = content
            }

            if let currentFileURL {
                documents[currentFileURL.standardizedFileURL] = currentContent
            }

            return documents
        }.value
    }

    private static func collectMarkdownFileURLs(from files: [WorkspaceFile]) -> [URL] {
        var urls: [URL] = []
        urls.reserveCapacity(files.count)

        func collect(_ nodes: [WorkspaceFile]) {
            for node in nodes {
                if node.isDirectory {
                    collect(node.children)
                    continue
                }
                let ext = node.url.pathExtension.lowercased()
                if ["md", "markdown", "mdown", "mkd"].contains(ext) {
                    urls.append(node.url.standardizedFileURL)
                }
            }
        }

        collect(files)

        // Keep indexing bounded for very large workspaces.
        if urls.count > 400 {
            return Array(urls.prefix(400))
        }
        return urls
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
