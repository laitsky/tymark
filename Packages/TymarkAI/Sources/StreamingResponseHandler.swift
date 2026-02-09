import Foundation

// MARK: - SSE Line Parser

/// Parses Server-Sent Events (SSE) from the Claude streaming API.
public enum SSEParser {

    /// Represents a parsed SSE event.
    public struct SSEEvent: Sendable {
        public let event: String?
        public let data: String
        public let id: String?

        public init(event: String? = nil, data: String, id: String? = nil) {
            self.event = event
            self.data = data
            self.id = id
        }
    }

    /// Parses a sequence of SSE lines into events.
    public static func parse(lines: [String]) -> [SSEEvent] {
        var events: [SSEEvent] = []
        var currentEvent: String? = nil
        var currentData: [String] = []
        var currentId: String? = nil

        for line in lines {
            if line.isEmpty {
                // Empty line = event boundary
                if !currentData.isEmpty {
                    let data = currentData.joined(separator: "\n")
                    events.append(SSEEvent(event: currentEvent, data: data, id: currentId))
                    currentEvent = nil
                    currentData = []
                    currentId = nil
                }
                continue
            }

            if line.hasPrefix("event:") {
                currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                currentData.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("id:") {
                currentId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            // Ignore comments (lines starting with :) and unknown fields
        }

        // Handle final event without trailing empty line
        if !currentData.isEmpty {
            let data = currentData.joined(separator: "\n")
            events.append(SSEEvent(event: currentEvent, data: data, id: currentId))
        }

        return events
    }
}

// MARK: - Claude Response Parser

/// Parses Claude API streaming response JSON objects.
public enum ClaudeResponseParser {

    public enum StreamEvent: Sendable {
        case textDelta(String)
        case messageStart
        case messageStop
        case contentBlockStart
        case contentBlockStop
        case error(String)
    }

    public static func parse(json: String) -> StreamEvent? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else {
            return nil
        }

        switch type {
        case "message_start":
            return .messageStart
        case "content_block_start":
            return .contentBlockStart
        case "content_block_delta":
            if let delta = obj["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                return .textDelta(text)
            }
            return nil
        case "content_block_stop":
            return .contentBlockStop
        case "message_stop":
            return .messageStop
        case "error":
            if let error = obj["error"] as? [String: Any],
               let message = error["message"] as? String {
                return .error(message)
            }
            return .error("Unknown error")
        default:
            return nil
        }
    }
}
