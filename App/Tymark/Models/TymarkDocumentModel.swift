import SwiftUI
import UniformTypeIdentifiers
import TymarkParser
import TymarkSync

// MARK: - Document Model (ReferenceFileDocument)

// @unchecked Sendable: Safe because ReferenceFileDocument is always accessed
// from the main thread by SwiftUI's document infrastructure.
final class TymarkDocumentModel: ReferenceFileDocument, @unchecked Sendable {

    @Published var content: String {
        didSet {
            updateMetadata()
        }
    }
    @Published var metadata: DocumentMetadata

    init(content: String = "") {
        self.content = content
        self.metadata = DocumentMetadata()
        updateMetadata()
    }

    private func updateMetadata() {
        metadata.modifiedAt = Date()
        metadata.characterCount = (content as NSString).length
        metadata.wordCount = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        metadata.title = MarkdownContentHelpers.extractTitle(from: content)
    }

    // MARK: - ReferenceFileDocument

    private static let supportedContentTypes: [UTType] = {
        // Keep ordering deterministic; SwiftUI uses these to wire document windows.
        var types: [UTType] = [.plainText]

        for ext in ["md", "markdown", "mdown", "mkd"] {
            guard let type = UTType(filenameExtension: ext) else { continue }
            guard type.conforms(to: .text) || type.conforms(to: .plainText) else { continue }
            if !types.contains(type) {
                types.append(type)
            }
        }

        return types
    }()

    static var readableContentTypes: [UTType] {
        supportedContentTypes
    }

    static var writableContentTypes: [UTType] {
        supportedContentTypes
    }

    convenience init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.init(content: string)
    }

    func snapshot(contentType: UTType) throws -> String {
        return content
    }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = snapshot.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Focused Values for Export

struct ExportActionKey: FocusedValueKey {
    typealias Value = (String) -> Void
}

extension FocusedValues {
    var exportAction: ExportActionKey.Value? {
        get { self[ExportActionKey.self] }
        set { self[ExportActionKey.self] = newValue }
    }
}
