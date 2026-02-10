import SwiftUI
import TymarkAI

// MARK: - AI Assistant State (Phase 8)

@MainActor
final class AIAssistantState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var selectedTask: AITaskType = .complete
    @Published var responseText: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var cursorVisible: Bool = true
    @Published var isUsingCloud: Bool = false

    private var currentEngine: (any AIServiceProtocol)?
    private var cursorTask: Task<Void, Never>?

    /// Callback to insert accepted text into the editor.
    var onAcceptResponse: ((String) -> Void)?

    init() {
        cursorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { break }
                self?.cursorVisible.toggle()
            }
        }
    }

    deinit {
        cursorTask?.cancel()
    }

    func run(text: String, context: String, configuration: AIConfiguration) {
        guard !text.isEmpty else { return }

        responseText = ""
        errorMessage = nil
        isProcessing = true

        let engine: any AIServiceProtocol
        switch configuration.selectedEngine {
        case .cloud:
            if configuration.hasAPIKey {
                engine = CloudAIEngine(configuration: configuration)
                isUsingCloud = true
            } else {
                errorMessage = "API key not configured. Set your API key in Settings to use Cloud AI."
                isProcessing = false
                return
            }
        case .auto:
            if configuration.hasAPIKey {
                engine = CloudAIEngine(configuration: configuration)
                isUsingCloud = true
            } else {
                engine = LocalAIEngine()
                isUsingCloud = false
            }
        case .local:
            engine = LocalAIEngine()
            isUsingCloud = false
        }
        currentEngine = engine

        let request = AIRequest(
            taskType: selectedTask,
            inputText: text,
            context: context
        )

        Task {
            do {
                for try await response in engine.process(request) {
                    switch response.type {
                    case .partial(let text):
                        self.responseText = text
                    case .complete(let text):
                        self.responseText = text
                        self.isProcessing = false
                    case .error(let message):
                        self.errorMessage = message
                        self.isProcessing = false
                    }
                }
                self.isProcessing = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }

    func cancel() {
        currentEngine?.cancel()
        isProcessing = false
    }

    func acceptResponse() {
        onAcceptResponse?(responseText)
        responseText = ""
    }

    func discardResponse() {
        responseText = ""
        errorMessage = nil
    }
}
