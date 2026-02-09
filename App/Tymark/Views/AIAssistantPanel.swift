import SwiftUI
import TymarkAI

// MARK: - AI Assistant Panel

struct AIAssistantPanel: View {
    @ObservedObject var state: AIAssistantState
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("AI Assistant")
                    .font(.headline)
                Spacer()

                // Engine indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(state.isUsingCloud ? Color.blue : Color.green)
                        .frame(width: 8, height: 8)
                    Text(state.isUsingCloud ? "Cloud" : "Local")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: { state.isVisible = false }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(12)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Task picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AITaskType.allCases, id: \.rawValue) { taskType in
                        Button(action: { state.selectedTask = taskType }) {
                            Text(taskType.rawValue)
                                .font(.system(size: 11))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    state.selectedTask == taskType
                                        ? Color.accentColor.opacity(0.2)
                                        : Color(.controlBackgroundColor)
                                )
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()

            // Response area
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if state.isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Processing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                    }

                    if !state.responseText.isEmpty {
                        Text(state.responseText)
                            .font(.system(size: 13))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)

                        if state.isProcessing {
                            // Blinking cursor
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 2, height: 16)
                                .opacity(state.cursorVisible ? 1 : 0)
                                .padding(.leading, 12)
                        }
                    }

                    if let error = state.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Action buttons
            HStack(spacing: 8) {
                if state.isProcessing {
                    Button("Cancel") {
                        state.cancel()
                    }
                    .controlSize(.small)
                } else if !state.responseText.isEmpty {
                    Button("Accept") {
                        state.acceptResponse()
                    }
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)

                    Button("Discard") {
                        state.discardResponse()
                    }
                    .controlSize(.small)
                } else {
                    Button("Run") {
                        if let manipulator = appState.activeTextManipulator {
                            let selectedText = manipulator.selectedText
                            let context = manipulator.fullText
                            state.run(
                                text: selectedText.isEmpty ? context : selectedText,
                                context: selectedText.isEmpty ? "" : context,
                                configuration: appState.aiConfiguration
                            )
                        }
                    }
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
                    .disabled(appState.activeTextManipulator == nil)
                }

                Spacer()
            }
            .padding(12)
        }
        .frame(width: 300)
        .background(Color(.windowBackgroundColor))
    }
}
