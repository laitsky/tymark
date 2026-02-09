import Foundation

// MARK: - Smart Typography Handler

/// Transforms straight quotes and other characters into typographically correct versions.
/// Disabled inside code blocks/fences.
public final class SmartTypographyHandler {

    public var isEnabled: Bool

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    /// Processes a typed character and returns the replacement string if smart typography applies.
    /// Returns `nil` if no transformation should be made.
    /// - Parameters:
    ///   - input: The character just typed
    ///   - textBefore: The text before the insertion point
    ///   - isInCodeBlock: Whether the cursor is inside a code block or inline code
    /// - Returns: The replacement string, or nil to keep original
    public func transform(_ input: String, textBefore: String, isInCodeBlock: Bool) -> String? {
        guard isEnabled && !isInCodeBlock else { return nil }

        switch input {
        case "\"":
            return transformDoubleQuote(textBefore: textBefore)
        case "'":
            return transformSingleQuote(textBefore: textBefore)
        case "-":
            return transformDash(textBefore: textBefore)
        case ".":
            return transformEllipsis(textBefore: textBefore)
        default:
            return nil
        }
    }

    // MARK: - Transformations

    private func transformDoubleQuote(textBefore: String) -> String {
        // Opening quote if preceded by whitespace, newline, or start of text
        if isOpeningPosition(textBefore: textBefore) {
            return "\u{201C}" // Left double quotation mark "
        } else {
            return "\u{201D}" // Right double quotation mark "
        }
    }

    private func transformSingleQuote(textBefore: String) -> String {
        // Opening quote if preceded by whitespace, newline, or start of text
        if isOpeningPosition(textBefore: textBefore) {
            return "\u{2018}" // Left single quotation mark '
        } else {
            return "\u{2019}" // Right single quotation mark ' (also apostrophe)
        }
    }

    private func transformDash(textBefore: String) -> String? {
        // Check if previous character is also a dash -> em-dash
        if textBefore.hasSuffix("-") {
            return "\u{2014}" // Em-dash —  (replaces the previous dash too)
        }
        return nil
    }

    private func transformEllipsis(textBefore: String) -> String? {
        // Check if two dots precede -> ellipsis
        if textBefore.hasSuffix("..") {
            return "\u{2026}" // Ellipsis …  (replaces the previous dots too)
        }
        return nil
    }

    // MARK: - Helpers

    private func isOpeningPosition(textBefore: String) -> Bool {
        guard let lastChar = textBefore.last else { return true }
        return lastChar.isWhitespace || lastChar.isNewline || lastChar == "(" || lastChar == "[" || lastChar == "{"
    }
}
