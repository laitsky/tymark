import Cocoa
import CryptoKit
import WebKit

// MARK: - Mermaid Renderer

/// Renders Mermaid diagram definitions to NSImage using a hidden WKWebView.
@MainActor
public final class MermaidRenderer {

    private var webView: WKWebView?
    private var cache: [String: NSImage] = [:]
    private var pendingRenders: [(definition: String, completion: (NSImage?) -> Void)] = []
    private var isRendering = false

    public init() {}

    /// Renders a Mermaid diagram definition to an NSImage.
    /// - Parameters:
    ///   - definition: The Mermaid diagram source code
    ///   - completion: Called with the rendered image, or nil on failure
    public func render(definition: String, completion: @escaping (NSImage?) -> Void) {
        // Check cache using content-based key
        let key = Self.cacheKey(for: definition)
        if let cached = cache[key] {
            completion(cached)
            return
        }

        // Queue the render if one is already in progress
        if isRendering {
            pendingRenders.append((definition, completion))
            return
        }

        performRender(definition: definition, key: key, completion: completion)
    }

    private func performRender(definition: String, key: String, completion: @escaping (NSImage?) -> Void) {
        isRendering = true
        let wv = getOrCreateWebView()

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { margin: 0; padding: 16px; background: transparent; }
                .mermaid { display: inline-block; }
            </style>
        </head>
        <body>
            <pre class="mermaid">\(escapeHTML(definition))</pre>
            <script type="module">
                import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
                mermaid.initialize({ startOnLoad: true, theme: 'default' });
                mermaid.run().then(() => {
                    setTimeout(() => {
                        window.webkit.messageHandlers.rendered.postMessage('done');
                    }, 500);
                }).catch(() => {
                    window.webkit.messageHandlers.rendered.postMessage('error');
                });
            </script>
        </body>
        </html>
        """

        // Set up message handler for completion
        let handler = MermaidMessageHandler { [weak self] in
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
        let key = Self.cacheKey(for: next.definition)

        // Check cache before rendering
        if let cached = cache[key] {
            next.completion(cached)
            processNextRender()
            return
        }

        performRender(definition: next.definition, key: key, completion: next.completion)
    }

    private func getOrCreateWebView() -> WKWebView {
        if let wv = webView { return wv }

        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        wv.isHidden = true
        webView = wv
        return wv
    }

    private static func cacheKey(for content: String) -> String {
        let hash = SHA256.hash(data: Data(content.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

// MARK: - Message Handler

private class MermaidMessageHandler: NSObject, WKScriptMessageHandler {
    let onRendered: () -> Void

    init(onRendered: @escaping () -> Void) {
        self.onRendered = onRendered
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        onRendered()
    }
}
