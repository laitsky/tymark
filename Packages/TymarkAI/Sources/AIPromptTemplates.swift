import Foundation

// MARK: - AI Prompt Templates

public enum AIPromptTemplates {

    /// Generates a prompt for the given AI request.
    public static func prompt(for request: AIRequest) -> String {
        switch request.taskType {
        case .complete:
            return completePrompt(text: request.inputText, context: request.context)
        case .summarize:
            return summarizePrompt(text: request.inputText)
        case .rewrite:
            return rewritePrompt(text: request.inputText, parameters: request.parameters)
        case .translate:
            return translatePrompt(text: request.inputText, parameters: request.parameters)
        case .fixGrammar:
            return fixGrammarPrompt(text: request.inputText)
        case .expandOutline:
            return expandOutlinePrompt(text: request.inputText)
        case .tone:
            return tonePrompt(text: request.inputText, parameters: request.parameters)
        }
    }

    // MARK: - Templates

    private static func completePrompt(text: String, context: String) -> String {
        """
        Continue writing the following text naturally. Match the style, tone, and format of the existing content. \
        Only output the continuation, not the original text.

        \(context.isEmpty ? "" : "Context:\n\(context)\n\n")Text to continue:
        \(text)
        """
    }

    private static func summarizePrompt(text: String) -> String {
        """
        Summarize the following text concisely. Preserve the key points and maintain \
        the same markdown formatting if applicable. Output only the summary.

        Text:
        \(text)
        """
    }

    private static func rewritePrompt(text: String, parameters: [String: String]) -> String {
        let style = parameters["style"] ?? "clearer and more concise"
        return """
        Rewrite the following text to be \(style). Maintain the same meaning \
        and markdown formatting. Output only the rewritten text.

        Text:
        \(text)
        """
    }

    private static func translatePrompt(text: String, parameters: [String: String]) -> String {
        let targetLanguage = parameters["language"] ?? "English"
        return """
        Translate the following text to \(targetLanguage). Preserve all markdown \
        formatting. Output only the translation.

        Text:
        \(text)
        """
    }

    private static func fixGrammarPrompt(text: String) -> String {
        """
        Fix any grammar, spelling, and punctuation errors in the following text. \
        Preserve the original meaning and markdown formatting. Only make necessary \
        corrections. Output only the corrected text.

        Text:
        \(text)
        """
    }

    private static func expandOutlinePrompt(text: String) -> String {
        """
        Expand the following outline into full prose. Each bullet point should become \
        a well-developed paragraph. Maintain markdown formatting with appropriate \
        headings. Output only the expanded text.

        Outline:
        \(text)
        """
    }

    private static func tonePrompt(text: String, parameters: [String: String]) -> String {
        let tone = parameters["tone"] ?? "professional"
        return """
        Rewrite the following text with a \(tone) tone. Maintain the same meaning \
        and markdown formatting. Output only the rewritten text.

        Text:
        \(text)
        """
    }
}
