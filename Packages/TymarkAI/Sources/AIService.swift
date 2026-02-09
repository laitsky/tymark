import Foundation
import os

// MARK: - Thread-Safe Value Wrapper

/// A simple thread-safe wrapper for mutable values using os_unfair_lock.
public final class LockedValue<T>: @unchecked Sendable {
    private var _value: T
    private let lock = OSAllocatedUnfairLock()

    public init(_ value: T) {
        self._value = value
    }

    public func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    public func set(_ newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        _value = newValue
    }
}

// MARK: - AI Task Types

public enum AITaskType: String, CaseIterable, Sendable {
    case complete = "Complete"
    case summarize = "Summarize"
    case rewrite = "Rewrite"
    case translate = "Translate"
    case fixGrammar = "Fix Grammar"
    case expandOutline = "Expand Outline"
    case tone = "Change Tone"
}

// MARK: - AI Request

public struct AIRequest: Sendable {
    public let taskType: AITaskType
    public let inputText: String
    public let context: String
    public let parameters: [String: String]

    public init(
        taskType: AITaskType,
        inputText: String,
        context: String = "",
        parameters: [String: String] = [:]
    ) {
        self.taskType = taskType
        self.inputText = inputText
        self.context = context
        self.parameters = parameters
    }
}

// MARK: - AI Response

public struct AIResponse: Sendable {
    public enum ResponseType: Sendable {
        case partial(text: String)
        case complete(text: String)
        case error(message: String)
    }

    public let type: ResponseType
    public let timestamp: Date

    public init(type: ResponseType, timestamp: Date = Date()) {
        self.type = type
        self.timestamp = timestamp
    }
}

// MARK: - AI Engine Selection

public enum AIEngineType: String, CaseIterable, Sendable {
    case local = "Local"
    case cloud = "Cloud"
    case auto = "Auto"
}

// MARK: - AI Service Protocol

public protocol AIServiceProtocol: AnyObject, Sendable {
    var isAvailable: Bool { get }
    var engineType: AIEngineType { get }
    func process(_ request: AIRequest) -> AsyncThrowingStream<AIResponse, Error>
    func cancel()
}
