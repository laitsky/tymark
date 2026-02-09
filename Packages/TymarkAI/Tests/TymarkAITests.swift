import XCTest
@testable import TymarkAI

final class TymarkAITests: XCTestCase {

    func testAITaskTypes() {
        XCTAssertEqual(AITaskType.allCases.count, 7)
        XCTAssertEqual(AITaskType.complete.rawValue, "Complete")
        XCTAssertEqual(AITaskType.summarize.rawValue, "Summarize")
    }

    func testAIRequest() {
        let request = AIRequest(
            taskType: .fixGrammar,
            inputText: "This is a test.",
            context: "Testing context"
        )

        XCTAssertEqual(request.taskType, .fixGrammar)
        XCTAssertEqual(request.inputText, "This is a test.")
        XCTAssertEqual(request.context, "Testing context")
    }

    func testAIPromptTemplates() {
        let request = AIRequest(taskType: .summarize, inputText: "Long text here")
        let prompt = AIPromptTemplates.prompt(for: request)
        XCTAssertTrue(prompt.contains("Summarize"))
        XCTAssertTrue(prompt.contains("Long text here"))
    }

    func testSSEParser() {
        let lines = [
            "event: message_start",
            "data: {\"type\":\"message_start\"}",
            "",
            "event: content_block_delta",
            "data: {\"type\":\"content_block_delta\",\"delta\":{\"text\":\"Hello\"}}",
            ""
        ]

        let events = SSEParser.parse(lines: lines)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].event, "message_start")
        XCTAssertEqual(events[1].event, "content_block_delta")
    }

    func testClaudeResponseParser() {
        let json = """
        {"type":"content_block_delta","delta":{"text":"Hello world"}}
        """

        let event = ClaudeResponseParser.parse(json: json)
        if case .textDelta(let text) = event {
            XCTAssertEqual(text, "Hello world")
        } else {
            XCTFail("Expected textDelta event")
        }
    }

    func testLocalAIEngineAvailability() {
        let engine = LocalAIEngine()
        XCTAssertTrue(engine.isAvailable)
        XCTAssertEqual(engine.engineType, .local)
    }
}
