import Cocoa
import CryptoKit
import WebKit

// MARK: - Math Renderer

/// Renders LaTeX math expressions to NSImage using KaTeX in a hidden WKWebView.
@MainActor
public final class MathRenderer {

    private var webView: WKWebView?
    private var cache: [String: NSImage] = [:]
    private var pendingRenders: [(latex: String, displayMode: Bool, completion: (NSImage?) -> Void)] = []
    private var isRendering = false

    public init() {}

    /// Renders a LaTeX math expression to an NSImage.
    /// - Parameters:
    ///   - latex: The LaTeX expression (without delimiters)
    ///   - displayMode: Whether to render in display mode (block) or inline
    ///   - completion: Called with the rendered image, or nil on failure
    public func render(latex: String, displayMode: Bool, completion: @escaping (NSImage?) -> Void) {
        let key = Self.cacheKey(for: latex, displayMode: displayMode)
        if let cached = cache[key] {
            completion(cached)
            return
        }

        // Queue the render if one is already in progress
        if isRendering {
            pendingRenders.append((latex, displayMode, completion))
            return
        }

        performRender(latex: latex, displayMode: displayMode, key: key, completion: completion)
    }

    private func performRender(latex: String, displayMode: Bool, key: String, completion: @escaping (NSImage?) -> Void) {
        isRendering = true
        let wv = getOrCreateWebView()

        let displayModeJS = displayMode ? "true" : "false"
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
            <style>
                body { margin: 0; padding: 8px; background: transparent; display: inline-block; }
                #math { display: inline-block; }
            </style>
        </head>
        <body>
            <span id="math"></span>
            <script>
                try {
                    katex.render(
                        `\(escapeJSString(latex))`,
                        document.getElementById('math'),
                        { displayMode: \(displayModeJS), throwOnError: false }
                    );
                    setTimeout(() => {
                        window.webkit.messageHandlers.rendered.postMessage('done');
                    }, 200);
                } catch(e) {
                    document.getElementById('math').textContent = 'Math error: ' + e.message;
                    window.webkit.messageHandlers.rendered.postMessage('done');
                }
            </script>
        </body>
        </html>
        """

        let handler = MathMessageHandler { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }

                let config = WKSnapshotConfiguration()
                config.afterScreenUpdates = true

                wv.takeSnapshot(with: config) { [weak self] image, error in
                    Task { @MainActor in
                        if let image = image {
                            self?.cache[key] = image
                            completion(image)
                        } else {
                            completion(nil)
                        }

                        // Clean up handler and process next in queue
                        wv.configuration.userContentController.removeAllScriptMessageHandlers()
                        self?.isRendering = false
                        self?.processNextRender()
                    }
                }
            }
        }

        wv.configuration.userContentController.removeAllScriptMessageHandlers()
        wv.configuration.userContentController.add(handler, name: "rendered")

        wv.loadHTMLString(html, baseURL: nil)
    }

    private func processNextRender() {
        guard !pendingRenders.isEmpty else { return }
        let next = pendingRenders.removeFirst()
        let key = Self.cacheKey(for: next.latex, displayMode: next.displayMode)

        // Check cache before rendering
        if let cached = cache[key] {
            next.completion(cached)
            processNextRender()
            return
        }

        performRender(latex: next.latex, displayMode: next.displayMode, key: key, completion: next.completion)
    }

    private func getOrCreateWebView() -> WKWebView {
        if let wv = webView { return wv }

        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 200), configuration: config)
        wv.isHidden = true
        webView = wv
        return wv
    }

    private static func cacheKey(for latex: String, displayMode: Bool) -> String {
        let input = "\(displayMode)-\(latex)"
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func escapeJSString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

// MARK: - Message Handler

private class MathMessageHandler: NSObject, WKScriptMessageHandler {
    let onRendered: () -> Void

    init(onRendered: @escaping () -> Void) {
        self.onRendered = onRendered
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        onRendered()
    }
}
