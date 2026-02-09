import Cocoa

// MARK: - Image Paste Handler

/// Handles pasting images from the clipboard into the markdown editor.
/// Saves images to the document's assets directory and inserts markdown image syntax.
public final class ImagePasteHandler {

    public init() {}

    /// Checks if the pasteboard contains an image.
    public func pasteboardContainsImage() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.canReadItem(
            withDataConformingToTypes: [
                NSPasteboard.PasteboardType.tiff.rawValue,
                NSPasteboard.PasteboardType.png.rawValue
            ]
        )
    }

    /// Handles pasting an image from the clipboard.
    /// - Parameters:
    ///   - documentURL: The URL of the current document (used to determine assets directory)
    ///   - insertAction: Closure called with the markdown text to insert
    /// - Returns: true if an image was handled, false otherwise
    public func handleImagePaste(documentURL: URL?, insertAction: (String) -> Void) -> Bool {
        let pasteboard = NSPasteboard.general

        guard let imageData = pasteboardImageData(from: pasteboard) else {
            return false
        }

        guard let docURL = documentURL else {
            // Document not saved yet - insert with a data URI or prompt to save
            insertAction("![Pasted Image](paste-image-save-document-first)")
            return true
        }

        // Create assets directory
        let assetsDir = docURL.deletingLastPathComponent().appendingPathComponent("assets")
        do {
            try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        } catch {
            return false
        }

        // Generate filename with timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "image-\(timestamp).png"
        let imageURL = assetsDir.appendingPathComponent(filename)

        // Convert to PNG and save
        guard let image = NSImage(data: imageData),
              let tiffRep = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffRep),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return false
        }

        do {
            try pngData.write(to: imageURL)
        } catch {
            return false
        }

        // Insert markdown image reference
        let relativePath = "assets/\(filename)"
        insertAction("![](\(relativePath))")

        return true
    }

    private func pasteboardImageData(from pasteboard: NSPasteboard) -> Data? {
        // Try PNG first
        if let data = pasteboard.data(forType: .png) {
            return data
        }
        // Fall back to TIFF
        if let data = pasteboard.data(forType: .tiff) {
            return data
        }
        return nil
    }
}
