import Foundation

// MARK: - Cloud AI Engine (Claude API)

/// Cloud-based AI engine using the Anthropic Claude API with streaming support.
public final class CloudAIEngine: AIServiceProtocol, @unchecked Sendable {

    public let engineType: AIEngineType = .cloud

    /// Captured API key and model (from MainActor at init time).
    private let storedAPIKey: String?
    private let storedModel: String
    private let _currentTask = LockedValue<Task<Void, Never>?>(nil)
    private let session: URLSession

    @MainActor
    public init(configuration: AIConfiguration) {
        self.storedAPIKey = configuration.apiKey
        self.storedModel = configuration.cloudModel
        self.session = URLSession(configuration: .default)
    }

    public var isAvailable: Bool {
        return storedAPIKey != nil && !storedAPIKey!.isEmpty
    }

    public func process(_ request: AIRequest) -> AsyncThrowingStream<AIResponse, Error> {
        let apiKey = storedAPIKey
        let model = storedModel

        return AsyncThrowingStream { [session] continuation in
            let task = Task {
                do {
                    guard let apiKey = apiKey else {
                        continuation.yield(AIResponse(type: .error(message: "API key not configured")))
                        continuation.finish()
                        return
                    }

                    let prompt = AIPromptTemplates.prompt(for: request)
                    let url = URL(string: "https://api.anthropic.com/v1/messages")!

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.timeoutInterval = 120
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 4096,
                        "stream": true,
                        "messages": [
                            ["role": "user", "content": prompt]
                        ]
                    ]

                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (asyncBytes, response) = try await session.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.yield(AIResponse(type: .error(message: "Invalid response")))
                        continuation.finish()
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        // Try to read the error body for a more helpful message
                        var errorBody = ""
                        for try await line in asyncBytes.lines {
                            errorBody += line
                            if errorBody.count > 1000 { break }
                        }
                        var message = "API error: HTTP \(httpResponse.statusCode)"
                        if let data = errorBody.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let error = json["error"] as? [String: Any],
                           let errorMessage = error["message"] as? String {
                            message = errorMessage
                        }
                        continuation.yield(AIResponse(type: .error(message: message)))
                        continuation.finish()
                        return
                    }

                    // Parse SSE stream
                    var accumulated = ""
                    for try await line in asyncBytes.lines {
                        if Task.isCancelled { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))

                        if jsonStr == "[DONE]" { break }

                        guard let data = jsonStr.data(using: .utf8),
                              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            continue
                        }

                        // Parse the streaming response
                        if let eventType = parsed["type"] as? String {
                            if eventType == "content_block_delta",
                               let delta = parsed["delta"] as? [String: Any],
                               let text = delta["text"] as? String {
                                accumulated += text
                                continuation.yield(AIResponse(type: .partial(text: accumulated)))
                            } else if eventType == "message_stop" {
                                break
                            }
                        }
                    }

                    continuation.yield(AIResponse(type: .complete(text: accumulated)))
                    continuation.finish()

                } catch {
                    if !Task.isCancelled {
                        continuation.yield(AIResponse(type: .error(message: error.localizedDescription)))
                    }
                    continuation.finish()
                }
            }

            self._currentTask.set(task)
        }
    }

    public func cancel() {
        let task = _currentTask.get()
        task?.cancel()
        _currentTask.set(nil)
    }
}
