#if canImport(XCTest)
import XCTest
import Foundation
@testable import TymarkSync

final class PreviewPerformanceBenchmarkTests: XCTestCase {
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
            "Performance benchmarks are opt-in. Run with \(benchmarkEnvVar)=1 swift test --filter PreviewPerformanceBenchmarkTests or create .tymark-run-perf-tests before running tests."
        )
    }

    private func generateMarkdown(paragraphCount: Int) -> String {
        var lines: [String] = []
        lines.reserveCapacity(paragraphCount * 3)

        for index in 1...paragraphCount {
            if index.isMultiple(of: 12) {
                lines.append("## Section \(index / 12 + 1)")
            }
            lines.append("Paragraph \(index) with **bold**, *italic*, and `inline code`.")
            lines.append("- Item \(index)")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    func testPreviewFrameGenerationFPS() {
        let provider = MarkdownPreviewProvider()
        let frames = 180
        let markdown = generateMarkdown(paragraphCount: 250)
        var observedFPS: [Double] = []

        measure {
            let start = ProcessInfo.processInfo.systemUptime
            for frame in 0..<frames {
                let progress = Double(frame) / Double(max(1, frames - 1))
                let frameMarkdown = "\(markdown)\n\n<!-- frame=\(frame) progress=\(progress) -->"
                _ = provider.generateHTMLBody(from: frameMarkdown)
            }
            let elapsed = max(ProcessInfo.processInfo.systemUptime - start, 0.000_001)
            observedFPS.append(Double(frames) / elapsed)
        }

        guard let worst = observedFPS.min() else {
            XCTFail("No FPS samples captured.")
            return
        }

        let sorted = observedFPS.sorted()
        let median = sorted[sorted.count / 2]
        XCTContext.runActivity(named: String(format: "Preview FPS median %.1f, worst %.1f", median, worst)) { _ in }

        XCTAssertGreaterThan(worst, 20, "Preview frame generation regression: worst-case FPS dropped below 20.")
    }

    func testPreviewDocumentRebuildLatency() {
        let provider = MarkdownPreviewProvider()
        let markdown = generateMarkdown(paragraphCount: 400)
        var observedMilliseconds: [Double] = []

        measure {
            let start = ProcessInfo.processInfo.systemUptime
            _ = provider.generateHTMLPreview(from: markdown, title: "Benchmark Document")
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            observedMilliseconds.append(elapsed * 1_000)
        }

        guard let worst = observedMilliseconds.max() else {
            XCTFail("No latency samples captured.")
            return
        }

        let sorted = observedMilliseconds.sorted()
        let median = sorted[sorted.count / 2]
        XCTContext.runActivity(named: String(format: "Preview rebuild median %.2fms, worst %.2fms", median, worst)) { _ in }

        XCTAssertLessThan(worst, 250, "Preview rebuild regression: worst-case latency exceeded 250ms.")
    }
}

#endif
