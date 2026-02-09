import SwiftUI
import TymarkAI

// MARK: - AI Inline Suggestion

/// Renders ghost text suggestions in the editor overlay.
struct AIInlineSuggestion: View {
    let suggestion: String
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if !suggestion.isEmpty {
            HStack(alignment: .top, spacing: 4) {
                Text(suggestion)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.5))
                    .lineLimit(3)

                VStack(spacing: 2) {
                    Text("Tab")
                        .font(.system(size: 9, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(.separatorColor).opacity(0.3))
                        .cornerRadius(2)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(.controlBackgroundColor).opacity(0.8))
            .cornerRadius(4)
            .onKeyPress(.tab) {
                onAccept()
                return .handled
            }
            .onKeyPress(.escape) {
                onDismiss()
                return .handled
            }
        }
    }
}
