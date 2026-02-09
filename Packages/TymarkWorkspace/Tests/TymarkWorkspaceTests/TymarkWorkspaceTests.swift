#if canImport(XCTest)
import XCTest
@testable import TymarkWorkspace

// MARK: - Workspace Tests

final class WorkspaceTests: XCTestCase {

    // MARK: - Initialization

    func testWorkspaceInitializationWithDefaults() {
        let workspace = Workspace(name: "MyProject")

        XCTAssertEqual(workspace.name, "MyProject")
        XCTAssertNil(workspace.rootURL)
        XCTAssertTrue(workspace.isExpanded)
        XCTAssertTrue(workspace.openFiles.isEmpty)
        XCTAssertNil(workspace.selectedFileID)
        XCTAssertTrue(workspace.recentFiles.isEmpty)
    }

    func testWorkspaceInitializationWithCustomValues() {
        let id = UUID()
        let rootURL = URL(fileURLWithPath: "/Users/test/project")
        let fileURL = URL(fileURLWithPath: "/Users/test/project/file.swift")
        let file = WorkspaceFile(url: fileURL)
        let selectedID = file.id
        let recentURL = URL(fileURLWithPath: "/Users/test/project/recent.md")

        let workspace = Workspace(
            id: id,
            name: "CustomWorkspace",
            rootURL: rootURL,
            isExpanded: false,
            openFiles: [file],
            selectedFileID: selectedID,
            recentFiles: [recentURL]
        )

        XCTAssertEqual(workspace.id, id)
        XCTAssertEqual(workspace.name, "CustomWorkspace")
        XCTAssertEqual(workspace.rootURL, rootURL)
        XCTAssertFalse(workspace.isExpanded)
        XCTAssertEqual(workspace.openFiles.count, 1)
        XCTAssertEqual(workspace.openFiles.first?.url, fileURL)
        XCTAssertEqual(workspace.selectedFileID, selectedID)
        XCTAssertEqual(workspace.recentFiles, [recentURL])
    }

    func testWorkspaceIsIdentifiable() {
        let workspace1 = Workspace(name: "A")
        let workspace2 = Workspace(name: "A")

        // Different UUIDs should make them different
        XCTAssertNotEqual(workspace1.id, workspace2.id)
    }

    func testWorkspaceEquality() {
        let id = UUID()
        let w1 = Workspace(id: id, name: "Test")
        let w2 = Workspace(id: id, name: "Test")

        XCTAssertEqual(w1, w2)
    }

    func testWorkspaceInequality() {
        let w1 = Workspace(name: "A")
        let w2 = Workspace(name: "B")

        XCTAssertNotEqual(w1, w2)
    }

    // MARK: - Codable

    func testWorkspaceCodableRoundTrip() throws {
        let rootURL = URL(fileURLWithPath: "/Users/test/project")
        let fileURL = URL(fileURLWithPath: "/Users/test/project/main.swift")
        let recentURL = URL(fileURLWithPath: "/Users/test/project/old.swift")
        let file = WorkspaceFile(url: fileURL, isDirectory: false)

        let original = Workspace(
            name: "CodableTest",
            rootURL: rootURL,
            isExpanded: false,
            openFiles: [file],
            selectedFileID: file.id,
            recentFiles: [recentURL]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Workspace.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.rootURL, original.rootURL)
        XCTAssertEqual(decoded.isExpanded, original.isExpanded)
        XCTAssertEqual(decoded.openFiles.count, original.openFiles.count)
        XCTAssertEqual(decoded.openFiles.first?.id, file.id)
        XCTAssertEqual(decoded.selectedFileID, original.selectedFileID)
        XCTAssertEqual(decoded.recentFiles, original.recentFiles)
    }

    func testWorkspaceCodableRoundTripWithNilOptionals() throws {
        let original = Workspace(name: "Minimal")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Workspace.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertNil(decoded.rootURL)
        XCTAssertTrue(decoded.isExpanded)
        XCTAssertTrue(decoded.openFiles.isEmpty)
        XCTAssertNil(decoded.selectedFileID)
        XCTAssertTrue(decoded.recentFiles.isEmpty)
    }
}

// MARK: - WorkspaceFile Tests

final class WorkspaceFileTests: XCTestCase {

    // MARK: - Initialization

    func testWorkspaceFileInitializationWithoutName() {
        let url = URL(fileURLWithPath: "/Users/test/project/README.md")
        let file = WorkspaceFile(url: url)

        XCTAssertEqual(file.url, url)
        XCTAssertEqual(file.name, "README.md", "Name should default to url.lastPathComponent")
        XCTAssertFalse(file.isDirectory)
        XCTAssertFalse(file.isExpanded)
        XCTAssertTrue(file.children.isEmpty)
        XCTAssertFalse(file.isSelected)
        XCTAssertFalse(file.isOpen)
        XCTAssertNil(file.modificationDate)
        XCTAssertNil(file.fileSize)
    }

    func testWorkspaceFileInitializationWithExplicitName() {
        let url = URL(fileURLWithPath: "/Users/test/project/file.txt")
        let file = WorkspaceFile(url: url, name: "CustomName")

        XCTAssertEqual(file.name, "CustomName")
        XCTAssertEqual(file.url, url)
    }

    func testWorkspaceFileInitializationWithNilNameDefaultsToLastPathComponent() {
        let url = URL(fileURLWithPath: "/deeply/nested/path/to/Document.pdf")
        let file = WorkspaceFile(url: url, name: nil)

        XCTAssertEqual(file.name, "Document.pdf")
    }

    func testWorkspaceFileInitializationWithAllCustomValues() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/Users/test/src")
        let childURL = URL(fileURLWithPath: "/Users/test/src/child.swift")
        let child = WorkspaceFile(url: childURL)
        let date = Date(timeIntervalSince1970: 1700000000)

        let file = WorkspaceFile(
            id: id,
            url: url,
            name: "Source",
            isDirectory: true,
            isExpanded: true,
            children: [child],
            isSelected: true,
            isOpen: true,
            modificationDate: date,
            fileSize: 4096
        )

        XCTAssertEqual(file.id, id)
        XCTAssertEqual(file.url, url)
        XCTAssertEqual(file.name, "Source")
        XCTAssertTrue(file.isDirectory)
        XCTAssertTrue(file.isExpanded)
        XCTAssertEqual(file.children.count, 1)
        XCTAssertEqual(file.children.first?.url, childURL)
        XCTAssertTrue(file.isSelected)
        XCTAssertTrue(file.isOpen)
        XCTAssertEqual(file.modificationDate, date)
        XCTAssertEqual(file.fileSize, 4096)
    }

    func testWorkspaceFileFileExtension() {
        let swiftFile = WorkspaceFile(url: URL(fileURLWithPath: "/test/file.swift"))
        XCTAssertEqual(swiftFile.fileExtension, "swift")

        let mdFile = WorkspaceFile(url: URL(fileURLWithPath: "/test/README.md"))
        XCTAssertEqual(mdFile.fileExtension, "md")

        let noExtFile = WorkspaceFile(url: URL(fileURLWithPath: "/test/Makefile"))
        XCTAssertEqual(noExtFile.fileExtension, "")
    }

    func testWorkspaceFileEquality() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/test/file.swift")

        let file1 = WorkspaceFile(id: id, url: url, name: "file.swift")
        let file2 = WorkspaceFile(id: id, url: url, name: "file.swift")

        XCTAssertEqual(file1, file2)
    }

    func testWorkspaceFileInequality() {
        let url = URL(fileURLWithPath: "/test/file.swift")

        let file1 = WorkspaceFile(url: url)
        let file2 = WorkspaceFile(url: url)

        // Different auto-generated UUIDs
        XCTAssertNotEqual(file1, file2)
    }

    // MARK: - Codable

    func testWorkspaceFileCodableRoundTrip() throws {
        let url = URL(fileURLWithPath: "/Users/test/file.swift")
        let date = Date(timeIntervalSince1970: 1700000000)

        let original = WorkspaceFile(
            url: url,
            name: "file.swift",
            isDirectory: false,
            isExpanded: false,
            children: [],
            isSelected: true,
            isOpen: true,
            modificationDate: date,
            fileSize: 1234
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkspaceFile.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.url, original.url)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.isDirectory, original.isDirectory)
        XCTAssertEqual(decoded.isExpanded, original.isExpanded)
        XCTAssertEqual(decoded.children.count, 0)
        XCTAssertEqual(decoded.isSelected, original.isSelected)
        XCTAssertEqual(decoded.isOpen, original.isOpen)
        XCTAssertEqual(decoded.modificationDate, original.modificationDate)
        XCTAssertEqual(decoded.fileSize, original.fileSize)
    }

    func testWorkspaceFileCodableRoundTripWithChildren() throws {
        let parentURL = URL(fileURLWithPath: "/Users/test/src")
        let childURL = URL(fileURLWithPath: "/Users/test/src/main.swift")
        let child = WorkspaceFile(url: childURL, isDirectory: false)

        let original = WorkspaceFile(
            url: parentURL,
            name: "src",
            isDirectory: true,
            isExpanded: true,
            children: [child]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkspaceFile.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertTrue(decoded.isDirectory)
        XCTAssertTrue(decoded.isExpanded)
        XCTAssertEqual(decoded.children.count, 1)
        XCTAssertEqual(decoded.children.first?.id, child.id)
        XCTAssertEqual(decoded.children.first?.url, childURL)
        XCTAssertEqual(decoded.children.first?.name, "main.swift")
    }

    func testWorkspaceFileCodableRoundTripWithNilOptionals() throws {
        let url = URL(fileURLWithPath: "/test/file.txt")
        let original = WorkspaceFile(url: url)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkspaceFile.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertNil(decoded.modificationDate)
        XCTAssertNil(decoded.fileSize)
    }
}

// MARK: - FuzzySearchEngine Tests

final class FuzzySearchEngineTests: XCTestCase {

    // MARK: - Helpers

    private func makeFile(name: String, isDirectory: Bool = false, children: [WorkspaceFile] = []) -> WorkspaceFile {
        let url = URL(fileURLWithPath: "/test/\(name)")
        return WorkspaceFile(
            url: url,
            name: name,
            isDirectory: isDirectory,
            children: children
        )
    }

    // MARK: - Empty Query

    func testSearchWithEmptyQueryReturnsEmpty() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "test.swift")])

        let results = engine.search(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testQuickOpenWithEmptyQueryReturnsEmpty() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "test.swift")])

        let results = engine.quickOpen(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Exact Match

    func testSearchExactMatchScoresOne() {
        let engine = FuzzySearchEngine()
        let file = makeFile(name: "main.swift")
        engine.index([file])

        let results = engine.search(query: "main.swift")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.score, 1.0, "Exact match should have a score of 1.0")
        XCTAssertEqual(results.first?.file.id, file.id)
    }

    func testSearchExactMatchIsCaseInsensitiveByDefault() {
        let engine = FuzzySearchEngine()
        let file = makeFile(name: "README.md")
        engine.index([file])

        let results = engine.search(query: "readme.md")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.score, 1.0, "Case-insensitive exact match should score 1.0")
    }

    func testSearchExactMatchMatchedRanges() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "hello.txt")])

        let results = engine.search(query: "hello.txt")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.matchedRanges.count, 1)

        let range = results.first!.matchedRanges.first!
        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, 9)
    }

    // MARK: - Substring Match

    func testSearchSubstringMatchAtStart() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "AppDelegate.swift")])

        let results = engine.search(query: "App")

        XCTAssertEqual(results.count, 1)
        // Substring match at start: 0.8 base + 0.1 start bonus + 0.05 no-slash bonus = 0.95
        let score = results.first!.score
        XCTAssertGreaterThanOrEqual(score, 0.8)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    func testSearchSubstringMatchInMiddle() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "MyAppDelegate.swift")])

        let results = engine.search(query: "App")

        XCTAssertEqual(results.count, 1)
        // Substring match not at start: 0.8 base + 0.05 no-slash bonus = 0.85
        let score = results.first!.score
        XCTAssertGreaterThanOrEqual(score, 0.8)
        XCTAssertLessThan(score, 1.0)
    }

    func testSearchSubstringMatchReturnsCorrectRange() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "ViewController.swift")])

        let results = engine.search(query: "Control")

        XCTAssertEqual(results.count, 1)
        let range = results.first!.matchedRanges.first!
        // "ViewController.swift" -> "Control" starts at index 4
        XCTAssertEqual(range.location, 4)
        XCTAssertEqual(range.length, 7)
    }

    // MARK: - Fuzzy Match

    func testSearchFuzzyMatchCharactersInOrderNotAdjacent() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "ViewController.swift")])

        // "vcs" should fuzzy match: V-iew-C-ontroller.-S-wift
        let results = engine.search(query: "vcs")

        XCTAssertFalse(results.isEmpty, "Fuzzy match should find characters in order")
        let score = results.first!.score
        XCTAssertGreaterThan(score, 0.0)
        XCTAssertLessThan(score, 0.8, "Fuzzy match score should be below substring match")
    }

    func testSearchFuzzyMatchReturnsMatchedRanges() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "abcdefgh")])

        let results = engine.search(query: "aceg")

        XCTAssertFalse(results.isEmpty)
        XCTAssertFalse(results.first!.matchedRanges.isEmpty)
    }

    // MARK: - No Match

    func testSearchNoMatchReturnsEmpty() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "main.swift")])

        let results = engine.search(query: "xyz123")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchNoMatchWhenCharactersOutOfOrder() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "abc")])

        // "cba" characters exist but not in order
        let results = engine.search(query: "cba")
        // This should either be empty or have a very low score below minScore
        // Since fuzzy match requires characters in order, it should fail
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Quick Open

    func testQuickOpenFindsMatch() {
        let engine = FuzzySearchEngine()
        let file = makeFile(name: "ContentView.swift")
        engine.index([file])

        let results = engine.quickOpen(query: "content")

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.file.id, file.id)
    }

    func testQuickOpenFuzzyMatch() {
        let engine = FuzzySearchEngine()
        let file = makeFile(name: "ViewController.swift")
        engine.index([file])

        let results = engine.quickOpen(query: "vc")

        XCTAssertFalse(results.isEmpty, "quickOpen should support fuzzy matching")
        XCTAssertEqual(results.first?.file.id, file.id)
    }

    func testQuickOpenNoMatchReturnsEmpty() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "main.swift")])

        let results = engine.quickOpen(query: "zzzz")
        XCTAssertTrue(results.isEmpty)
    }

    func testQuickOpenMatchedRangesAreEmpty() {
        let engine = FuzzySearchEngine()
        engine.index([makeFile(name: "test.swift")])

        let results = engine.quickOpen(query: "test")

        XCTAssertFalse(results.isEmpty)
        // quickOpen uses simplified matching and returns empty matchedRanges
        XCTAssertTrue(results.first!.matchedRanges.isEmpty)
    }

    // MARK: - Max Results Limit

    func testSearchRespectsMaxResultsLimit() {
        let config = FuzzySearchEngine.Configuration(
            caseSensitive: false,
            maxResults: 3,
            minScore: 0.0,
            searchContent: true
        )
        let engine = FuzzySearchEngine(configuration: config)

        // Index many files that all contain "file"
        var files: [WorkspaceFile] = []
        for i in 0..<10 {
            files.append(makeFile(name: "file\(i).swift"))
        }
        engine.index(files)

        let results = engine.search(query: "file")

        XCTAssertEqual(results.count, 3, "Results should be limited to maxResults")
    }

    func testQuickOpenRespectsMaxResultsLimit() {
        let config = FuzzySearchEngine.Configuration(
            caseSensitive: false,
            maxResults: 2,
            minScore: 0.0,
            searchContent: true
        )
        let engine = FuzzySearchEngine(configuration: config)

        var files: [WorkspaceFile] = []
        for i in 0..<10 {
            files.append(makeFile(name: "item\(i).txt"))
        }
        engine.index(files)

        let results = engine.quickOpen(query: "item")

        XCTAssertEqual(results.count, 2, "quickOpen should also respect maxResults limit")
    }

    // MARK: - Index Flattens Directory Children

    func testIndexFlattensDirectoryChildren() {
        let engine = FuzzySearchEngine()

        let childFile = makeFile(name: "nested.swift")
        let directory = makeFile(name: "Sources", isDirectory: true, children: [childFile])

        engine.index([directory])

        // Both the directory and the child file should be searchable
        let dirResults = engine.search(query: "Sources")
        XCTAssertFalse(dirResults.isEmpty, "Directory itself should be indexed")

        let childResults = engine.search(query: "nested.swift")
        XCTAssertFalse(childResults.isEmpty, "Nested child file should be indexed after flattening")
    }

    func testIndexFlattensDeeplyNestedChildren() {
        let engine = FuzzySearchEngine()

        let deepFile = makeFile(name: "deep.swift")
        let innerDir = makeFile(name: "Inner", isDirectory: true, children: [deepFile])
        let outerDir = makeFile(name: "Outer", isDirectory: true, children: [innerDir])

        engine.index([outerDir])

        let results = engine.search(query: "deep.swift")
        XCTAssertFalse(results.isEmpty, "Deeply nested files should be reachable after flattening")
    }

    func testIndexEmptyDirectoryDoesNotFlattenChildren() {
        let engine = FuzzySearchEngine()

        // A directory with isDirectory = true but empty children
        let emptyDir = makeFile(name: "EmptyDir", isDirectory: true, children: [])
        engine.index([emptyDir])

        let results = engine.search(query: "EmptyDir")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Case Sensitivity

    func testSearchCaseSensitiveConfiguration() {
        let config = FuzzySearchEngine.Configuration(
            caseSensitive: true,
            maxResults: 50,
            minScore: 0.3,
            searchContent: true
        )
        let engine = FuzzySearchEngine(configuration: config)
        engine.index([makeFile(name: "README.md")])

        let lowerResults = engine.search(query: "readme.md")
        XCTAssertTrue(lowerResults.isEmpty, "Case-sensitive search should not match different case")

        let exactResults = engine.search(query: "README.md")
        XCTAssertEqual(exactResults.count, 1)
        XCTAssertEqual(exactResults.first?.score, 1.0)
    }

    // MARK: - Configuration Defaults

    func testDefaultConfiguration() {
        let config = FuzzySearchEngine.Configuration.default

        XCTAssertFalse(config.caseSensitive)
        XCTAssertEqual(config.maxResults, 50)
        XCTAssertEqual(config.minScore, 0.3, accuracy: 0.001)
        XCTAssertTrue(config.searchContent)
    }

    // MARK: - Min Score Filtering

    func testSearchRespectsMinScoreThreshold() {
        let config = FuzzySearchEngine.Configuration(
            caseSensitive: false,
            maxResults: 50,
            minScore: 0.99,
            searchContent: true
        )
        let engine = FuzzySearchEngine(configuration: config)
        engine.index([makeFile(name: "ViewController.swift")])

        // A partial substring match should score below 0.99 and be filtered
        let results = engine.search(query: "View")
        // "View" is a substring at start -> score = 0.8 + 0.1 + 0.05 = 0.95
        XCTAssertTrue(results.isEmpty, "Results below minScore should be filtered out")
    }

    // MARK: - Multiple Files Search

    func testSearchRanksResultsByScore() {
        let engine = FuzzySearchEngine()

        let exactMatch = makeFile(name: "query.txt")
        let substringMatch = makeFile(name: "myquery.txt")
        let fuzzyMatch = makeFile(name: "qzuzezrzyz.txt")

        engine.index([fuzzyMatch, substringMatch, exactMatch])

        let results = engine.search(query: "query")

        XCTAssertGreaterThanOrEqual(results.count, 2)
        // Results should be sorted by score descending
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(
                results[i].score,
                results[i + 1].score,
                "Results should be sorted with higher scores first"
            )
        }
    }

    // MARK: - Re-indexing

    func testReindexReplacesOldFiles() {
        let engine = FuzzySearchEngine()

        engine.index([makeFile(name: "old.swift")])
        let oldResults = engine.search(query: "old.swift")
        XCTAssertEqual(oldResults.count, 1)

        engine.index([makeFile(name: "new.swift")])
        let oldAfterReindex = engine.search(query: "old.swift")
        XCTAssertTrue(oldAfterReindex.isEmpty, "Old files should not appear after re-indexing")

        let newResults = engine.search(query: "new.swift")
        XCTAssertEqual(newResults.count, 1)
    }
}

// MARK: - SearchResult Tests

final class SearchResultTests: XCTestCase {

    private func makeFile(name: String) -> WorkspaceFile {
        let url = URL(fileURLWithPath: "/test/\(name)")
        return WorkspaceFile(url: url, name: name)
    }

    func testSearchResultComparableHigherScoreFirst() {
        let file1 = makeFile(name: "a.swift")
        let file2 = makeFile(name: "b.swift")

        let highScore = SearchResult(file: file1, score: 0.9, matchedRanges: [])
        let lowScore = SearchResult(file: file2, score: 0.5, matchedRanges: [])

        // The < operator is defined so higher score comes first
        XCTAssertTrue(highScore < lowScore, "Higher score should sort before lower score")
        XCTAssertFalse(lowScore < highScore)
    }

    func testSearchResultSortingOrderDescendingByScore() {
        let file1 = makeFile(name: "a.swift")
        let file2 = makeFile(name: "b.swift")
        let file3 = makeFile(name: "c.swift")

        var results = [
            SearchResult(file: file2, score: 0.5, matchedRanges: []),
            SearchResult(file: file1, score: 0.9, matchedRanges: []),
            SearchResult(file: file3, score: 0.7, matchedRanges: []),
        ]

        results.sort()

        XCTAssertEqual(results[0].score, 0.9)
        XCTAssertEqual(results[1].score, 0.7)
        XCTAssertEqual(results[2].score, 0.5)
    }

    func testSearchResultEqualityBasedOnFileIDAndScore() {
        let file = makeFile(name: "test.swift")

        let result1 = SearchResult(file: file, score: 0.8, matchedRanges: [NSRange(location: 0, length: 4)])
        let result2 = SearchResult(file: file, score: 0.8, matchedRanges: [])

        // Equality is based on file.id and score, not matchedRanges
        XCTAssertEqual(result1, result2)
    }

    func testSearchResultInequalityDifferentScores() {
        let file = makeFile(name: "test.swift")

        let result1 = SearchResult(file: file, score: 0.8, matchedRanges: [])
        let result2 = SearchResult(file: file, score: 0.6, matchedRanges: [])

        XCTAssertNotEqual(result1, result2)
    }

    func testSearchResultInequalityDifferentFiles() {
        let file1 = makeFile(name: "a.swift")
        let file2 = makeFile(name: "b.swift")

        let result1 = SearchResult(file: file1, score: 0.8, matchedRanges: [])
        let result2 = SearchResult(file: file2, score: 0.8, matchedRanges: [])

        XCTAssertNotEqual(result1, result2)
    }

    func testSearchResultEqualScoresAreNotLessThan() {
        let file1 = makeFile(name: "a.swift")
        let file2 = makeFile(name: "b.swift")

        let result1 = SearchResult(file: file1, score: 0.8, matchedRanges: [])
        let result2 = SearchResult(file: file2, score: 0.8, matchedRanges: [])

        XCTAssertFalse(result1 < result2, "Equal scores should not compare as less than")
        XCTAssertFalse(result2 < result1)
    }
}

// MARK: - FileOutlineProvider Tests

final class FileOutlineProviderTests: XCTestCase {

    // MARK: - No Headings

    func testGenerateOutlineWithNoHeadings() {
        let source = """
        This is just a paragraph of text.
        No headings here.
        Just plain content.
        """

        let items = FileOutlineProvider.generateOutline(from: source)
        XCTAssertTrue(items.isEmpty, "Source without headings should produce an empty outline")
    }

    func testGenerateOutlineWithEmptyString() {
        let items = FileOutlineProvider.generateOutline(from: "")
        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - Single Headings (h1 through h6)

    func testGenerateOutlineExtractsH1() {
        let source = "# Title"
        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Title")
        XCTAssertEqual(items.first?.level, 1)

        if case .heading(let level) = items.first?.type {
            XCTAssertEqual(level, 1)
        } else {
            XCTFail("Expected heading type")
        }
    }

    func testGenerateOutlineExtractsH2() {
        let source = "## Section"
        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Section")
        XCTAssertEqual(items.first?.level, 2)

        if case .heading(let level) = items.first?.type {
            XCTAssertEqual(level, 2)
        } else {
            XCTFail("Expected heading type")
        }
    }

    func testGenerateOutlineExtractsH3() {
        let source = "### Subsection"
        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Subsection")
        XCTAssertEqual(items.first?.level, 3)
    }

    func testGenerateOutlineExtractsH4() {
        let source = "#### Deep"
        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Deep")
        XCTAssertEqual(items.first?.level, 4)
    }

    func testGenerateOutlineExtractsH5() {
        let source = "##### Deeper"
        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Deeper")
        XCTAssertEqual(items.first?.level, 5)
    }

    func testGenerateOutlineExtractsH6() {
        let source = "###### Deepest"
        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Deepest")
        XCTAssertEqual(items.first?.level, 6)
    }

    // MARK: - Multiple Headings

    func testGenerateOutlineExtractsMultipleHeadings() {
        let source = """
        # Introduction
        Some text here.
        ## Background
        More text.
        ## Methods
        Details.
        ### Data Collection
        Info about data.
        ## Results
        """

        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 5)

        XCTAssertEqual(items[0].title, "Introduction")
        XCTAssertEqual(items[0].level, 1)

        XCTAssertEqual(items[1].title, "Background")
        XCTAssertEqual(items[1].level, 2)

        XCTAssertEqual(items[2].title, "Methods")
        XCTAssertEqual(items[2].level, 2)

        XCTAssertEqual(items[3].title, "Data Collection")
        XCTAssertEqual(items[3].level, 3)

        XCTAssertEqual(items[4].title, "Results")
        XCTAssertEqual(items[4].level, 2)
    }

    func testGenerateOutlineAllLevels() {
        let source = """
        # H1
        ## H2
        ### H3
        #### H4
        ##### H5
        ###### H6
        """

        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 6)
        for i in 0..<6 {
            XCTAssertEqual(items[i].level, i + 1)
            XCTAssertEqual(items[i].title, "H\(i + 1)")

            if case .heading(let level) = items[i].type {
                XCTAssertEqual(level, i + 1)
            } else {
                XCTFail("Expected heading type at index \(i)")
            }
        }
    }

    // MARK: - Heading Ranges

    func testGenerateOutlineHeadingRanges() {
        let source = "# First\n## Second"
        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 2)

        // First heading starts at offset 0, length of "# First" = 7
        XCTAssertEqual(items[0].range.location, 0)
        XCTAssertEqual(items[0].range.length, 7)

        // Second heading starts at offset 8 (after "# First\n"), length of "## Second" = 9
        XCTAssertEqual(items[1].range.location, 8)
        XCTAssertEqual(items[1].range.length, 9)
    }

    // MARK: - Edge Cases

    func testGenerateOutlineIgnoresMoreThanSixHashes() {
        let source = "####### Not a heading"
        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertTrue(items.isEmpty, "More than 6 hashes should not be treated as a heading")
    }

    func testGenerateOutlineHeadingWithoutSpace() {
        // "#Title" without a space after the hash - the implementation drops the
        // hash prefix and checks for a space; if no space, the title is everything after hashes
        let source = "#NoSpace"
        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 1)
        // The implementation: afterHashes = "NoSpace", hasPrefix(" ") is false, so title = "NoSpace"
        XCTAssertEqual(items.first?.title, "NoSpace")
    }

    func testGenerateOutlineWithLeadingWhitespace() {
        let source = "  ## Indented Heading"
        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Indented Heading")
        XCTAssertEqual(items.first?.level, 2)
    }

    func testGenerateOutlineNonHeadingLinesIgnored() {
        let source = """
        Regular paragraph.
        - A list item
        > A blockquote
        ```
        code block
        ```
        # Actual Heading
        """

        let items = FileOutlineProvider.generateOutline(from: source)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Actual Heading")
    }

    func testGenerateOutlineEachItemHasUniqueID() {
        let source = """
        # One
        ## Two
        ### Three
        """

        let items = FileOutlineProvider.generateOutline(from: source)
        let ids = items.map { $0.id }
        let uniqueIDs = Set(ids)

        XCTAssertEqual(ids.count, uniqueIDs.count, "All outline items should have unique IDs")
    }
}

#endif
