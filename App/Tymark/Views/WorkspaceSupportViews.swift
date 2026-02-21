import SwiftUI
import AppKit
import WebKit
import TymarkEditor
import TymarkTheme
import TymarkSync
import TymarkWorkspace

// MARK: - Status Bar

struct DocumentTabStrip: View {
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

struct MinimapView: View {
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

struct WorkspaceStatusBar: View {
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

struct InspectorPane: View {
    let outlineItems: [DocumentOutlineItem]
    let metadata: DocumentMetadata
    let statistics: DocumentStatistics
    let backlinks: [BacklinkHit]
    let documentTags: [String]
    let workspaceTagCounts: [TagCount]
    let selectedTag: String?
    let taggedFiles: [URL]
    let onJump: (DocumentOutlineItem) -> Void
    let onReorder: (IndexSet, Int) -> Void
    let onOpenBacklink: (URL) -> Void
    let onSelectTag: (String?) -> Void
    let onOpenTaggedFile: (URL) -> Void
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

                GroupBox("Backlinks") {
                    VStack(alignment: .leading, spacing: 6) {
                        if backlinks.isEmpty {
                            Text("No linked references yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(backlinks, id: \.sourceURL) { hit in
                                Button {
                                    onOpenBacklink(hit.sourceURL)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.uturn.backward.circle")
                                            .foregroundColor(.secondary)
                                        Text(hit.sourceURL.lastPathComponent)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                        Text("\(hit.referenceCount)x")
                                            .font(.caption2.monospaced())
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(hit.sourceURL.path(percentEncoded: false))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Tags") {
                    VStack(alignment: .leading, spacing: 8) {
                        if documentTags.isEmpty {
                            Text("No tags in this document")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Document")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            tagFlow(documentTags, selectedTag: selectedTag, onSelectTag: onSelectTag)
                        }

                        Divider()

                        HStack {
                            Text("Workspace")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(workspaceTagCounts.count) tags")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if workspaceTagCounts.isEmpty {
                            Text("No tags indexed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            tagFlow(
                                workspaceTagCounts.map(\.tag),
                                selectedTag: selectedTag,
                                onSelectTag: onSelectTag,
                                counts: Dictionary(uniqueKeysWithValues: workspaceTagCounts.map { ($0.tag, $0.count) })
                            )
                        }

                        if let selectedTag {
                            Divider()
                            HStack {
                                Text("Files tagged #\(selectedTag)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Clear") {
                                    onSelectTag(nil)
                                }
                                .buttonStyle(.plain)
                                .font(.caption2)
                            }

                            if taggedFiles.isEmpty {
                                Text("No files match this tag")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(taggedFiles, id: \.self) { url in
                                    Button {
                                        onOpenTaggedFile(url)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "number")
                                                .foregroundColor(.secondary)
                                            Text(url.lastPathComponent)
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .help(url.path(percentEncoded: false))
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

    private func tagFlow(
        _ tags: [String],
        selectedTag: String?,
        onSelectTag: @escaping (String?) -> Void,
        counts: [String: Int] = [:]
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    onSelectTag(selectedTag == tag ? nil : tag)
                } label: {
                    HStack(spacing: 4) {
                        Text("#\(tag)")
                            .lineLimit(1)
                        if let count = counts[tag] {
                            Text("\(count)")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill((selectedTag == tag ? Color.accentColor.opacity(0.2) : Color(.controlBackgroundColor)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                selectedTag == tag ? Color.accentColor.opacity(0.55) : Color(.separatorColor).opacity(0.45),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview Rendering

@MainActor
final class MarkdownPreviewViewModel: ObservableObject {
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

struct MarkdownPreviewView: NSViewRepresentable {
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

struct DocumentOutlineItem: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let level: Int
    let lineNumber: Int
    let location: Int
    let length: Int
}

struct DerivedDocumentData: Sendable {
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
