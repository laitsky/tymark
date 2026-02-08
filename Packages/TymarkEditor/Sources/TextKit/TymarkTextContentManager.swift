import Cocoa
import TymarkParser

// MARK: - Text Content Manager

public final class TymarkTextContentManager: NSTextContentManager {

    // MARK: - Properties

    private var textStorage: NSTextStorage?
    private var document: TymarkDocument?
    private var parser: IncrementalParser

    // MARK: - Initialization

    public init(textStorage: NSTextStorage? = nil) {
        self.parser = IncrementalParser()
        self.textStorage = textStorage
        super.init()
    }

    required init?(coder: NSCoder) {
        self.parser = IncrementalParser()
        super.init(coder: coder)
    }

    // MARK: - NSTextContentManager Overrides

    public override var documentRange: NSTextRange {
        let length = textStorage?.length ?? 0
        let startLoc = TymarkTextLocation(offset: 0, provider: self)
        let endLoc = TymarkTextLocation(offset: length, provider: self)
        return NSTextRange(location: startLoc, end: endLoc)!
    }

    public override func location(_ location: NSTextLocation, offsetBy offset: Int) -> NSTextLocation? {
        guard let loc = location as? TymarkTextLocation else { return nil }
        let newOffset = loc.offset + offset
        guard newOffset >= 0 else { return nil }
        return TymarkTextLocation(offset: newOffset, provider: self)
    }

    public override func offset(from: NSTextLocation, to: NSTextLocation) -> Int {
        guard let fromLoc = from as? TymarkTextLocation,
              let toLoc = to as? TymarkTextLocation else { return 0 }
        return toLoc.offset - fromLoc.offset
    }

    // MARK: - Public API

    public func setSource(_ source: String) {
        document = parser.parse(source)
        // Notify observers of content change
        self.textStorage?.notifyObservers()
    }

    public func updateSource(_ edit: TextEdit, newSource: String) -> IncrementalUpdateInfo {
        guard let currentDoc = document else {
            document = parser.parse(newSource)
            return IncrementalUpdateInfo(
                affectedRange: edit.range,
                nodesToReparse: document?.root.children ?? [],
                isStructuralChange: true
            )
        }

        let (newDoc, updateInfo) = parser.update(document: currentDoc, with: edit, newSource: newSource)
        document = newDoc

        return updateInfo
    }

    public var currentDocument: TymarkDocument? {
        return document
    }
}

// MARK: - Custom Text Location

public final class TymarkTextLocation: NSObject, NSTextLocation {
    private let _offset: Int
    private weak var _provider: TymarkTextContentManager?

    public var offset: Int { return _offset }

    public init(offset: Int, provider: TymarkTextContentManager?) {
        self._offset = offset
        self._provider = provider
        super.init()
    }

    public func compare(_ location: NSTextLocation) -> ComparisonResult {
        guard let other = location as? TymarkTextLocation else {
            return .orderedSame
        }

        if _offset < other._offset {
            return .orderedAscending
        } else if _offset > other._offset {
            return .orderedDescending
        }
        return .orderedSame
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? TymarkTextLocation else { return false }
        return _offset == other._offset && _provider === other._provider
    }

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(_offset)
        if let provider = _provider {
            hasher.combine(ObjectIdentifier(provider))
        }
        return hasher.finalize()
    }
}

// MARK: - NSTextStorage Extensions

extension NSTextStorage {
    func notifyObservers() {
        // Trigger notifications for text storage changes
        self.edited(.editedCharacters, range: NSRange(location: 0, length: length), changeInLength: 0)
    }
}
