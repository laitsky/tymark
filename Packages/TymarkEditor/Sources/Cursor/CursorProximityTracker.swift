import Foundation
import TymarkParser

// MARK: - Cursor Proximity Tracker Delegate

public protocol CursorProximityTrackerDelegate: AnyObject {
    func cursorProximityTracker(_ tracker: CursorProximityTracker, didUpdateLocation location: Int)
    func cursorProximityTracker(_ tracker: CursorProximityTracker, didEnterNode node: TymarkNode)
    func cursorProximityTracker(_ tracker: CursorProximityTracker, didExitNode node: TymarkNode)
}

// Default implementations so conformers only need to implement what they use
public extension CursorProximityTrackerDelegate {
    func cursorProximityTracker(_ tracker: CursorProximityTracker, didEnterNode node: TymarkNode) {}
    func cursorProximityTracker(_ tracker: CursorProximityTracker, didExitNode node: TymarkNode) {}
}

// MARK: - Cursor Proximity Tracker

public final class CursorProximityTracker {

    // MARK: - Properties

    public weak var delegate: CursorProximityTrackerDelegate?

    private var currentLocation: Int = 0
    private var currentNode: TymarkNode?
    private var proximityThreshold: Int = 10 // Characters

    private var activeNodes: Set<UUID> = []
    private var pendingExits: Set<UUID> = []

    // MARK: - Initialization

    public init(proximityThreshold: Int = 10) {
        self.proximityThreshold = proximityThreshold
    }

    // MARK: - Public API

    public func updateCursorLocation(_ location: Int) {
        let previousLocation = currentLocation
        currentLocation = location

        // Notify delegate of location change
        delegate?.cursorProximityTracker(self, didUpdateLocation: location)

        // Check for node transitions
        detectNodeTransitions(from: previousLocation, to: location)
    }

    public func updateNodes(_ nodes: [TymarkNode]) {
        // Update the set of active nodes based on current cursor location
        let previouslyActive = activeNodes
        activeNodes.removeAll()

        for node in nodes {
            if isNearCursor(node) {
                activeNodes.insert(node.id)

                // Check for new entries
                if !previouslyActive.contains(node.id) {
                    delegate?.cursorProximityTracker(self, didEnterNode: node)
                }
            }
        }

        // Check for exits
        for nodeID in previouslyActive {
            if !activeNodes.contains(nodeID) {
                // Find the node and notify exit
                if let node = findNode(with: nodeID, in: nodes) {
                    delegate?.cursorProximityTracker(self, didExitNode: node)
                }
            }
        }
    }

    public func clear() {
        currentLocation = 0
        currentNode = nil
        activeNodes.removeAll()
        pendingExits.removeAll()
    }

    // MARK: - Private Methods

    private func detectNodeTransitions(from oldLocation: Int, to newLocation: Int) {
        // Determine if cursor crossed any significant boundaries
        let movedForward = newLocation > oldLocation
        let distance = abs(newLocation - oldLocation)

        // Skip processing for small movements
        if distance == 0 { return }

        // Update the current node
        // This would be called with the actual document structure
    }

    private func isNearCursor(_ node: TymarkNode) -> Bool {
        // Check if cursor is inside the node
        if NSLocationInRange(currentLocation, node.range) {
            return true
        }

        // Check if cursor is within threshold distance
        let startDistance = abs(currentLocation - node.range.location)
        let endDistance = abs(currentLocation - NSMaxRange(node.range))

        return min(startDistance, endDistance) <= proximityThreshold
    }

    private func findNode(with id: UUID, in nodes: [TymarkNode]) -> TymarkNode? {
        for node in nodes {
            if node.id == id {
                return node
            }
            if let found = findNode(with: id, in: node.children) {
                return found
            }
        }
        return nil
    }

    // MARK: - Utility

    public func getNodesInProximity(from document: TymarkDocument) -> [TymarkNode] {
        return findNodesInRange(currentLocation - proximityThreshold,
                                to: currentLocation + proximityThreshold,
                                in: document.root)
    }

    private func findNodesInRange(_ start: Int, to end: Int, in node: TymarkNode) -> [TymarkNode] {
        var results: [TymarkNode] = []
        let searchRange = NSRange(location: max(0, start), length: end - start)

        if NSIntersectionRange(node.range, searchRange).length > 0 {
            results.append(node)

            for child in node.children {
                results.append(contentsOf: findNodesInRange(start, to: end, in: child))
            }
        }

        return results
    }
}

// MARK: - Selection Manager

public final class SelectionManager {

    // MARK: - Properties

    private var currentSelection: NSRange = NSRange(location: 0, length: 0)
    private var selectionHistory: [NSRange] = []
    private let maxHistorySize = 50

    public var onSelectionChanged: ((NSRange) -> Void)?

    // MARK: - Public API

    public func updateSelection(_ range: NSRange) {
        // Save to history
        selectionHistory.append(currentSelection)
        if selectionHistory.count > maxHistorySize {
            selectionHistory.removeFirst()
        }

        currentSelection = range
        onSelectionChanged?(range)
    }

    public func selectWord(at location: Int) -> NSRange {
        // Find word boundaries
        let wordRange = NSRange(location: location, length: 0) // Placeholder
        updateSelection(wordRange)
        return wordRange
    }

    public func selectLine(at location: Int) -> NSRange {
        // Find line boundaries
        let lineRange = NSRange(location: location, length: 0) // Placeholder
        updateSelection(lineRange)
        return lineRange
    }

    public func selectBlock(_ node: TymarkNode) -> NSRange {
        updateSelection(node.range)
        return node.range
    }

    public func moveToPreviousBlock(in document: TymarkDocument) -> NSRange? {
        guard let currentBlock = findBlockContaining(currentSelection.location, in: document.root) else {
            return nil
        }

        // Find previous sibling block
        if let previousBlock = findPreviousSibling(of: currentBlock, in: document.root) {
            let newSelection = NSRange(location: previousBlock.range.location, length: 0)
            updateSelection(newSelection)
            return newSelection
        }

        return nil
    }

    public func moveToNextBlock(in document: TymarkDocument) -> NSRange? {
        guard let currentBlock = findBlockContaining(currentSelection.location, in: document.root) else {
            return nil
        }

        // Find next sibling block
        if let nextBlock = findNextSibling(of: currentBlock, in: document.root) {
            let newSelection = NSRange(location: nextBlock.range.location, length: 0)
            updateSelection(newSelection)
            return newSelection
        }

        return nil
    }

    public func undoSelection() -> NSRange? {
        guard !selectionHistory.isEmpty else { return nil }
        let previous = selectionHistory.removeLast()
        currentSelection = previous
        return previous
    }

    // MARK: - Private Methods

    private func findBlockContaining(_ location: Int, in node: TymarkNode) -> TymarkNode? {
        if !NSLocationInRange(location, node.range) {
            return nil
        }

        for child in node.children where child.isBlock {
            if let found = findBlockContaining(location, in: child) {
                return found
            }
        }

        return node.isBlock ? node : nil
    }

    private func findPreviousSibling(of target: TymarkNode, in node: TymarkNode) -> TymarkNode? {
        var foundIndex: Int?

        for (index, child) in node.children.enumerated() {
            if child.id == target.id {
                foundIndex = index
                break
            }
            if let found = findPreviousSibling(of: target, in: child) {
                return found
            }
        }

        if let index = foundIndex, index > 0 {
            return node.children[index - 1]
        }

        return nil
    }

    private func findNextSibling(of target: TymarkNode, in node: TymarkNode) -> TymarkNode? {
        var foundIndex: Int?

        for (index, child) in node.children.enumerated() {
            if child.id == target.id {
                foundIndex = index
                break
            }
            if let found = findNextSibling(of: target, in: child) {
                return found
            }
        }

        if let index = foundIndex, index < node.children.count - 1 {
            return node.children[index + 1]
        }

        return nil
    }
}
