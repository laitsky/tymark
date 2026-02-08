import Foundation

// MARK: - Diff Types

public enum ASTChangeType: Equatable {
    case unchanged
    case modified
    case inserted
    case deleted
}

public struct ASTDiffResult: Equatable {
    public let node: TymarkNode
    public let changeType: ASTChangeType
    public let oldRange: NSRange?
    public let newRange: NSRange?
    public let childDiffs: [ASTDiffResult]

    public init(
        node: TymarkNode,
        changeType: ASTChangeType,
        oldRange: NSRange? = nil,
        newRange: NSRange? = nil,
        childDiffs: [ASTDiffResult] = []
    ) {
        self.node = node
        self.changeType = changeType
        self.oldRange = oldRange
        self.newRange = newRange
        self.childDiffs = childDiffs
    }
}

// MARK: - AST Diff Engine

public final class ASTDiff {

    public init() {}

    public func diff(oldDocument: TymarkDocument, newDocument: TymarkDocument) -> [ASTDiffResult] {
        return diffNodes(old: oldDocument.root, new: newDocument.root)
    }

    private func diffNodes(old: TymarkNode, new: TymarkNode) -> [ASTDiffResult] {
        var results: [ASTDiffResult] = []

        // If types differ, the whole subtree changed
        if old.type != new.type {
            results.append(ASTDiffResult(
                node: new,
                changeType: .modified,
                oldRange: old.range,
                newRange: new.range
            ))
            return results
        }

        // If content differs, this node was modified
        let contentChanged = old.content != new.content
        let rangeChanged = !NSEqualRanges(old.range, new.range)

        if contentChanged || rangeChanged {
            results.append(ASTDiffResult(
                node: new,
                changeType: .modified,
                oldRange: old.range,
                newRange: new.range
            ))
        } else {
            results.append(ASTDiffResult(
                node: new,
                changeType: .unchanged,
                oldRange: old.range,
                newRange: new.range
            ))
        }

        // Diff children
        let childResults = diffChildren(oldChildren: old.children, newChildren: new.children)
        results.append(contentsOf: childResults)

        return results
    }

    private func diffChildren(oldChildren: [TymarkNode], newChildren: [TymarkNode]) -> [ASTDiffResult] {
        var results: [ASTDiffResult] = []
        var oldIndex = 0
        var newIndex = 0

        while oldIndex < oldChildren.count || newIndex < newChildren.count {
            if oldIndex >= oldChildren.count {
                // Remaining new children are inserted
                let newChild = newChildren[newIndex]
                results.append(ASTDiffResult(
                    node: newChild,
                    changeType: .inserted,
                    newRange: newChild.range
                ))
                newIndex += 1
            } else if newIndex >= newChildren.count {
                // Remaining old children are deleted
                let oldChild = oldChildren[oldIndex]
                results.append(ASTDiffResult(
                    node: oldChild,
                    changeType: .deleted,
                    oldRange: oldChild.range
                ))
                oldIndex += 1
            } else {
                let oldChild = oldChildren[oldIndex]
                let newChild = newChildren[newIndex]

                // Check if nodes are similar enough to compare
                if areNodesSimilar(oldChild, newChild) {
                    let childDiffs = diffNodes(old: oldChild, new: newChild)
                    results.append(contentsOf: childDiffs)
                    oldIndex += 1
                    newIndex += 1
                } else if shouldInsertNew(oldChild, newChild) {
                    results.append(ASTDiffResult(
                        node: newChild,
                        changeType: .inserted,
                        newRange: newChild.range
                    ))
                    newIndex += 1
                } else {
                    results.append(ASTDiffResult(
                        node: oldChild,
                        changeType: .deleted,
                        oldRange: oldChild.range
                    ))
                    oldIndex += 1
                }
            }
        }

        return results
    }

    private func areNodesSimilar(_ old: TymarkNode, _ new: TymarkNode) -> Bool {
        // Same type and overlapping or adjacent ranges suggest same node
        if old.type != new.type {
            return false
        }

        let rangeOverlap = NSMaxRange(old.range) >= new.range.location &&
                          NSMaxRange(new.range) >= old.range.location

        return rangeOverlap || old.content == new.content
    }

    private func shouldInsertNew(_ old: TymarkNode, _ new: TymarkNode) -> Bool {
        // If the new node starts before the old node, it's likely an insertion
        return new.range.location < old.range.location
    }
}

// MARK: - Incremental Update Info

public struct IncrementalUpdateInfo {
    public let affectedRange: NSRange
    public let nodesToReparse: [TymarkNode]
    public let isStructuralChange: Bool

    public init(
        affectedRange: NSRange,
        nodesToReparse: [TymarkNode],
        isStructuralChange: Bool
    ) {
        self.affectedRange = affectedRange
        self.nodesToReparse = nodesToReparse
        self.isStructuralChange = isStructuralChange
    }
}

extension ASTDiff {
    public func computeIncrementalUpdate(
        from oldDocument: TymarkDocument,
        to newDocument: TymarkDocument,
        editRange: NSRange
    ) -> IncrementalUpdateInfo {
        let diffResults = diff(oldDocument: oldDocument, newDocument: newDocument)

        // Collect all modified nodes
        let modifiedNodes = diffResults.filter { $0.changeType != .unchanged }

        // Check for structural changes (block-level changes)
        let structuralChanges = modifiedNodes.filter { $0.node.isBlock }
        let isStructural = !structuralChanges.isEmpty

        // Compute affected range
        var affectedRange = editRange
        for result in modifiedNodes {
            if let range = result.newRange {
                affectedRange = NSUnionRange(affectedRange, range)
            }
            if let range = result.oldRange {
                affectedRange = NSUnionRange(affectedRange, range)
            }
        }

        // Find nodes that need re-parsing
        let nodesToReparse = modifiedNodes.map { $0.node }

        return IncrementalUpdateInfo(
            affectedRange: affectedRange,
            nodesToReparse: nodesToReparse,
            isStructuralChange: isStructural
        )
    }
}
