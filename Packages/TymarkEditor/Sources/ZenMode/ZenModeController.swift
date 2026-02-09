import Cocoa

// MARK: - Zen Mode Controller

@MainActor
public final class ZenModeController {

    private weak var window: NSWindow?
    private var savedToolbarVisibility: Bool = true
    private var isActive: Bool = false

    public init() {}

    public func toggle(window: NSWindow?) {
        guard let window = window else { return }
        self.window = window

        if isActive {
            deactivate()
        } else {
            activate(window: window)
        }
    }

    private func activate(window: NSWindow) {
        // Save current state
        savedToolbarVisibility = window.toolbar?.isVisible ?? true

        // Hide toolbar
        window.toolbar?.isVisible = false

        // Enter fullscreen
        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }

        isActive = true
    }

    private func deactivate() {
        guard let window = window else { return }

        // Exit fullscreen
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }

        // Restore toolbar
        window.toolbar?.isVisible = savedToolbarVisibility

        isActive = false
    }
}
