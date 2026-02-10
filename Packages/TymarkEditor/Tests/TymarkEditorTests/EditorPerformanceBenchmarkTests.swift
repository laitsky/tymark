#if canImport(XCTest)
import XCTest
import Foundation
@testable import TymarkEditor

final class EditorPerformanceBenchmarkTests: XCTestCase {
    private static let benchmarkEnvVar = "TYMARK_RUN_PERF_TESTS"

    override func setUpWithError() throws {
        try super.setUpWithError()
        try Self.requireBenchmarksEnabled()
    }

    private static func requireBenchmarksEnabled() throws {
        let processInfo = ProcessInfo.processInfo
        let envEnabled = processInfo.environment[benchmarkEnvVar] == "1"
        let argEnabled = processInfo.arguments.contains("--run-perf")
        let markerPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".tymark-run-perf-tests")
            .path
        let fileEnabled = FileManager.default.fileExists(atPath: markerPath)
        let enabled = envEnabled || argEnabled || fileEnabled
        try XCTSkipUnless(
            enabled,
            "Performance benchmarks are opt-in. Run with \(benchmarkEnvVar)=1 swift test --filter EditorPerformanceBenchmarkTests or create .tymark-run-perf-tests before running tests."
        )
    }

    private func generateTypingStream(length: Int) -> String {
        let fragments = [
            "The quick brown fox ",
            "jumps over ",
            "\"quoted text\" ",
            "and -- punctuation... ",
            "`code` and *emphasis* ",
            "(brackets) [links] "
        ]
        var output = ""
        output.reserveCapacity(length + 128)
        var index = 0
        while output.utf16.count < length {
            output += fragments[index % fragments.count]
            index += 1
        }
        return String(output.prefix(length))
    }

    private func runTypingPipeline(input: String) -> Int {
        let pairHandler = SmartPairHandler()
        let typography = SmartTypographyHandler(isEnabled: true)
        let buffer = NSMutableString()

        for character in input {
            let inputChar = String(character)
            let current = buffer as String
            let transformed = typography.transform(inputChar, textBefore: current, isInCodeBlock: false) ?? inputChar

            for transformedChar in transformed {
                if let replacement = pairHandler.handleInsertion(of: transformedChar, at: buffer.length, in: buffer as String) {
                    if !replacement.isEmpty {
                        buffer.append(replacement)
                    }
                } else {
                    buffer.append(String(transformedChar))
                }
            }
        }

        return buffer.length
    }

    func testTypingPipelineLatency() {
        let stream = generateTypingStream(length: 4000)
        let keystrokes = max(1, stream.utf16.count)
        var observedMicroseconds: [Double] = []

        measure {
            let start = ProcessInfo.processInfo.systemUptime
            let finalLength = runTypingPipeline(input: stream)
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            XCTAssertGreaterThan(finalLength, 0)
            observedMicroseconds.append((elapsed / Double(keystrokes)) * 1_000_000)
        }

        guard let worst = observedMicroseconds.max() else {
            XCTFail("No latency samples captured.")
            return
        }

        let sorted = observedMicroseconds.sorted()
        let median = sorted[sorted.count / 2]
        XCTContext.runActivity(named: String(format: "Typing latency median %.1fµs, worst %.1fµs", median, worst)) { _ in }

        XCTAssertLessThan(worst, 5_000, "Typing latency regression: worst-case keystroke exceeded 5ms.")
    }

    func testTypingPipelineThroughputCharactersPerSecond() {
        let stream = generateTypingStream(length: 6000)
        let insertions = max(1, stream.utf16.count)
        var observedCPS: [Double] = []

        measure {
            let start = ProcessInfo.processInfo.systemUptime
            let finalLength = runTypingPipeline(input: stream)
            let elapsed = max(ProcessInfo.processInfo.systemUptime - start, 0.000_001)
            XCTAssertGreaterThan(finalLength, 0)
            observedCPS.append(Double(insertions) / elapsed)
        }

        guard let slowest = observedCPS.min() else {
            XCTFail("No throughput samples captured.")
            return
        }

        let sorted = observedCPS.sorted()
        let median = sorted[sorted.count / 2]
        XCTContext.runActivity(named: String(format: "Typing throughput median %.1f cps, slowest %.1f cps", median, slowest)) { _ in }

        XCTAssertGreaterThan(slowest, 250, "Typing throughput regression: slowest run dropped below 250 chars/s.")
    }
}

#endif
