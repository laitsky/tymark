import Foundation

// MARK: - Wikilinks

public struct WikilinkReference: Equatable, Sendable {
    public let rawTarget: String
    public let normalizedTarget: String
    public let isEmbedded: Bool

    public init(rawTarget: String, normalizedTarget: String, isEmbedded: Bool) {
        self.rawTarget = rawTarget
        self.normalizedTarget = normalizedTarget
        self.isEmbedded = isEmbedded
    }
}

// MARK: - Tags

public struct TagCount: Equatable, Sendable {
    public let tag: String
    public let count: Int

    public init(tag: String, count: Int) {
        self.tag = tag
        self.count = count
    }
}

// MARK: - Backlinks

public struct BacklinkHit: Equatable, Sendable {
    public let sourceURL: URL
    public let referenceCount: Int

    public init(sourceURL: URL, referenceCount: Int) {
        self.sourceURL = sourceURL
        self.referenceCount = referenceCount
    }
}

// MARK: - Markdown Knowledge Parser

public enum MarkdownKnowledgeParser {
    private enum RegexCache {
        static let wikilink = try? NSRegularExpression(pattern: #"(!)?\[\[([^\]\n]+)\]\]"#)
        static let tag = try? NSRegularExpression(pattern: #"(?<![#\w])#([A-Za-z][A-Za-z0-9_/-]*)"#)
        static let inlineCode = try? NSRegularExpression(pattern: #"`[^`\n]+`"#)
    }

    public static func extractWikilinks(from source: String) -> [WikilinkReference] {
        guard let regex = RegexCache.wikilink else { return [] }
        let nsSource = source as NSString
        let matches = regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length))
        guard !matches.isEmpty else { return [] }

        var links: [WikilinkReference] = []
        links.reserveCapacity(matches.count)

        for match in matches {
            let targetRange = match.range(at: 2)
            guard targetRange.location != NSNotFound else { continue }
            let rawTarget = nsSource.substring(with: targetRange)
            let normalized = normalizeWikilinkTarget(rawTarget)
            guard !normalized.isEmpty else { continue }
            links.append(WikilinkReference(
                rawTarget: rawTarget,
                normalizedTarget: normalized,
                isEmbedded: match.range(at: 1).location != NSNotFound
            ))
        }

        return links
    }

    public static func extractTags(from source: String) -> [String] {
        guard let regex = RegexCache.tag else { return [] }
        let lines = source.components(separatedBy: .newlines)
        var inFencedCodeBlock = false
        var inFrontMatter = false

        var orderedTags: [String] = []
        var seenTags: Set<String> = []

        for (lineNumber, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if lineNumber == 0, trimmed == "---" {
                inFrontMatter = true
                continue
            }
            if inFrontMatter {
                if trimmed == "---" || trimmed == "..." {
                    inFrontMatter = false
                }
                continue
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFencedCodeBlock.toggle()
                continue
            }
            if inFencedCodeBlock || trimmed.isEmpty {
                continue
            }

            if looksLikeHeading(trimmed) {
                continue
            }

            var scanLine = line
            if let inlineCodeRegex = RegexCache.inlineCode {
                let nsLine = scanLine as NSString
                scanLine = inlineCodeRegex.stringByReplacingMatches(
                    in: scanLine,
                    range: NSRange(location: 0, length: nsLine.length),
                    withTemplate: " "
                )
            }

            let nsScanLine = scanLine as NSString
            let matches = regex.matches(
                in: scanLine,
                range: NSRange(location: 0, length: nsScanLine.length)
            )

            for match in matches {
                let tagRange = match.range(at: 1)
                guard tagRange.location != NSNotFound else { continue }
                let normalized = nsScanLine.substring(with: tagRange).lowercased()
                guard seenTags.insert(normalized).inserted else { continue }
                orderedTags.append(normalized)
            }
        }

        return orderedTags
    }

    public static func normalizeWikilinkTarget(_ target: String) -> String {
        var normalized = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        if let aliasIndex = normalized.firstIndex(of: "|") {
            normalized = String(normalized[..<aliasIndex])
        }
        if let fragmentIndex = normalized.firstIndex(of: "#") {
            normalized = String(normalized[..<fragmentIndex])
        }

        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized.replacingOccurrences(of: "\\", with: "/")
        while normalized.hasPrefix("./") {
            normalized.removeFirst(2)
        }
        while normalized.hasPrefix("/") {
            normalized.removeFirst()
        }

        if normalized.lowercased().hasSuffix(".md") {
            normalized = String(normalized.dropLast(3))
        }

        return normalized.lowercased()
    }

    public static func candidateTargets(for fileURL: URL) -> [String] {
        var candidates: Set<String> = []

        let fileName = fileURL.deletingPathExtension().lastPathComponent.lowercased()
        if !fileName.isEmpty {
            candidates.insert(fileName)
        }

        var components = fileURL.pathComponents.filter { component in
            !component.isEmpty && component != "/"
        }
        guard !components.isEmpty else {
            return Array(candidates)
        }

        let lastIndex = components.count - 1
        components[lastIndex] = (components[lastIndex] as NSString).deletingPathExtension
        guard !components[lastIndex].isEmpty else {
            return Array(candidates)
        }

        for start in components.indices {
            let suffix = components[start...].joined(separator: "/").lowercased()
            candidates.insert(suffix)
        }

        return Array(candidates)
    }

    private static func looksLikeHeading(_ line: String) -> Bool {
        guard line.hasPrefix("#") else { return false }
        let hashes = line.prefix { $0 == "#" }.count
        guard hashes >= 1 && hashes <= 6 else { return false }
        guard line.count > hashes else { return false }
        let index = line.index(line.startIndex, offsetBy: hashes)
        return line[index] == " "
    }
}

// MARK: - Workspace Knowledge Index

public struct WorkspaceKnowledgeIndex: Sendable {
    private let backlinkCountsByTarget: [String: [URL: Int]]
    private let tagsByFileStorage: [URL: [String]]
    private let filesByTagStorage: [String: [URL]]

    public init(documents: [URL: String]) {
        var backlinkCountsByTarget: [String: [URL: Int]] = [:]
        var tagsByFile: [URL: [String]] = [:]
        var filesByTagSet: [String: Set<URL>] = [:]

        for (sourceURL, source) in documents {
            for link in MarkdownKnowledgeParser.extractWikilinks(from: source) {
                backlinkCountsByTarget[link.normalizedTarget, default: [:]][sourceURL, default: 0] += 1
            }

            let tags = MarkdownKnowledgeParser.extractTags(from: source)
            tagsByFile[sourceURL] = tags
            for tag in Set(tags) {
                filesByTagSet[tag, default: []].insert(sourceURL)
            }
        }

        self.backlinkCountsByTarget = backlinkCountsByTarget
        self.tagsByFileStorage = tagsByFile
        self.filesByTagStorage = filesByTagSet.mapValues { urls in
            urls.sorted(by: Self.urlSort)
        }
    }

    public static func build(from documents: [URL: String]) -> WorkspaceKnowledgeIndex {
        WorkspaceKnowledgeIndex(documents: documents)
    }

    public func backlinks(for fileURL: URL) -> [BacklinkHit] {
        let targets = MarkdownKnowledgeParser.candidateTargets(for: fileURL)
        guard !targets.isEmpty else { return [] }

        var countsByURL: [URL: Int] = [:]
        for target in targets {
            guard let targetCounts = backlinkCountsByTarget[target] else { continue }
            for (sourceURL, count) in targetCounts where sourceURL != fileURL {
                countsByURL[sourceURL, default: 0] += count
            }
        }

        return countsByURL
            .map { BacklinkHit(sourceURL: $0.key, referenceCount: $0.value) }
            .sorted { lhs, rhs in
                if lhs.referenceCount != rhs.referenceCount {
                    return lhs.referenceCount > rhs.referenceCount
                }
                return Self.urlSort(lhs.sourceURL, rhs.sourceURL)
            }
    }

    public func tags(for fileURL: URL) -> [String] {
        tagsByFileStorage[fileURL] ?? []
    }

    public func files(matchingTag tag: String) -> [URL] {
        filesByTagStorage[tag.lowercased()] ?? []
    }

    public var tagCounts: [TagCount] {
        filesByTagStorage
            .map { TagCount(tag: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.tag < rhs.tag
            }
    }

    private static func urlSort(_ lhs: URL, _ rhs: URL) -> Bool {
        let lhsName = lhs.lastPathComponent.lowercased()
        let rhsName = rhs.lastPathComponent.lowercased()
        if lhsName != rhsName {
            return lhsName < rhsName
        }
        return lhs.path.lowercased() < rhs.path.lowercased()
    }
}
