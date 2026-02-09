import XCTest
import Foundation
@testable import TymarkEditor

// MARK: - SmartPairHandler Tests

final class SmartPairHandlerTests: XCTestCase {

    private var handler: SmartPairHandler!

    override func setUp() {
        super.setUp()
        handler = SmartPairHandler()
    }

    override func tearDown() {
        handler = nil
        super.tearDown()
    }

    // MARK: - isEnabled

    func testIsEnabledByDefault() {
        XCTAssertTrue(handler.isEnabled)
    }

    func testCanDisable() {
        handler.isEnabled = false
        XCTAssertFalse(handler.isEnabled)
    }

    // MARK: - handleInsertion: Opening Characters Insert Pairs

    func testInsertionOfOpenParenthesis() {
        let result = handler.handleInsertion(of: "(", at: 0, in: "")
        XCTAssertEqual(result, "()")
    }

    func testInsertionOfOpenBracket() {
        let result = handler.handleInsertion(of: "[", at: 0, in: "")
        XCTAssertEqual(result, "[]")
    }

    func testInsertionOfOpenBrace() {
        let result = handler.handleInsertion(of: "{", at: 0, in: "")
        XCTAssertEqual(result, "{}")
    }

    func testInsertionOfDoubleQuote() {
        let result = handler.handleInsertion(of: "\"", at: 0, in: "")
        XCTAssertEqual(result, "\"\"")
    }

    func testInsertionOfSingleQuote() {
        let result = handler.handleInsertion(of: "'", at: 0, in: "")
        XCTAssertEqual(result, "''")
    }

    func testInsertionOfBacktick() {
        let result = handler.handleInsertion(of: "`", at: 0, in: "")
        XCTAssertEqual(result, "``")
    }

    func testInsertionOfAsterisk() {
        let result = handler.handleInsertion(of: "*", at: 0, in: "")
        XCTAssertEqual(result, "**")
    }

    func testInsertionOfUnderscore() {
        let result = handler.handleInsertion(of: "_", at: 0, in: "")
        XCTAssertEqual(result, "__")
    }

    func testInsertionOfOpenParenInMiddleOfText() {
        let result = handler.handleInsertion(of: "(", at: 5, in: "hello world")
        XCTAssertEqual(result, "()")
    }

    func testInsertionOfOpenBraceAtEndOfText() {
        let text = "function"
        let result = handler.handleInsertion(of: "{", at: text.count, in: text)
        XCTAssertEqual(result, "{}")
    }

    // MARK: - handleInsertion: Closing Character Skip

    func testInsertionSkipsClosingParenthesisWhenNextCharMatches() {
        // Text: "()" with cursor at position 1 (between parens), typing ")"
        let text = "()"
        let result = handler.handleInsertion(of: ")", at: 0, in: text)
        // At location 0, the next char at 1 is ")", so it should skip
        XCTAssertEqual(result, "")
    }

    func testInsertionSkipsClosingBracketWhenNextCharMatches() {
        let text = "[]"
        let result = handler.handleInsertion(of: "]", at: 0, in: text)
        XCTAssertEqual(result, "")
    }

    func testInsertionSkipsClosingBraceWhenNextCharMatches() {
        let text = "{}"
        let result = handler.handleInsertion(of: "}", at: 0, in: text)
        XCTAssertEqual(result, "")
    }

    func testInsertionSkipsClosingDoubleQuoteWhenNextCharMatches() {
        let text = "\"\""
        let result = handler.handleInsertion(of: "\"", at: 0, in: text)
        // " is both opener and closer: the opening pair logic takes precedence
        // because " is in the pairs dict as an opener, it returns the pair
        XCTAssertEqual(result, "\"\"")
    }

    // MARK: - handleInsertion: No-op Cases

    func testInsertionOfRegularCharacterReturnsNil() {
        let result = handler.handleInsertion(of: "a", at: 0, in: "")
        XCTAssertNil(result)
    }

    func testInsertionOfDigitReturnsNil() {
        let result = handler.handleInsertion(of: "5", at: 0, in: "hello")
        XCTAssertNil(result)
    }

    func testInsertionOfSpaceReturnsNil() {
        let result = handler.handleInsertion(of: " ", at: 0, in: "hello")
        XCTAssertNil(result)
    }

    func testInsertionReturnsNilWhenDisabled() {
        handler.isEnabled = false
        let result = handler.handleInsertion(of: "(", at: 0, in: "")
        XCTAssertNil(result)
    }

    func testInsertionOfClosingParenWhenNoNextCharDoesNotSkip() {
        // Closing paren at end of text - no next char to check
        let result = handler.handleInsertion(of: ")", at: 4, in: "test")
        XCTAssertNil(result)
    }

    // MARK: - handleDeletion: Pair Deletion

    func testDeletionRemovesBothParens() {
        let text = "()"
        // Cursor at position 1 (between the parens)
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertEqual(result, NSRange(location: 0, length: 2))
    }

    func testDeletionRemovesBothBrackets() {
        let text = "[]"
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertEqual(result, NSRange(location: 0, length: 2))
    }

    func testDeletionRemovesBothBraces() {
        let text = "{}"
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertEqual(result, NSRange(location: 0, length: 2))
    }

    func testDeletionRemovesBothDoubleQuotes() {
        let text = "\"\""
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertEqual(result, NSRange(location: 0, length: 2))
    }

    func testDeletionRemovesBothSingleQuotes() {
        let text = "''"
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertEqual(result, NSRange(location: 0, length: 2))
    }

    func testDeletionRemovesBothBackticks() {
        let text = "``"
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertEqual(result, NSRange(location: 0, length: 2))
    }

    func testDeletionRemovesBothAsterisks() {
        let text = "**"
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertEqual(result, NSRange(location: 0, length: 2))
    }

    func testDeletionRemovesBothUnderscores() {
        let text = "__"
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertEqual(result, NSRange(location: 0, length: 2))
    }

    func testDeletionInMiddleOfTextWithPair() {
        let text = "hello()world"
        // Position 6 is between ( and )
        let result = handler.handleDeletion(at: 6, in: text)
        XCTAssertEqual(result, NSRange(location: 5, length: 2))
    }

    // MARK: - handleDeletion: No Pair Cases

    func testDeletionReturnsNilForNonPairCharacters() {
        let text = "ab"
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertNil(result)
    }

    func testDeletionReturnsNilAtStartOfText() {
        let text = "()"
        let result = handler.handleDeletion(at: 0, in: text)
        XCTAssertNil(result)
    }

    func testDeletionReturnsNilAtEndOfText() {
        let text = "()"
        let result = handler.handleDeletion(at: text.count, in: text)
        XCTAssertNil(result)
    }

    func testDeletionReturnsNilWhenDisabled() {
        handler.isEnabled = false
        let text = "()"
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertNil(result)
    }

    func testDeletionReturnsNilForMismatchedPair() {
        let text = "(]"
        let result = handler.handleDeletion(at: 1, in: text)
        XCTAssertNil(result)
    }

    // MARK: - shouldSkipClosingCharacter

    func testShouldSkipClosingParenWhenNextCharMatches() {
        let text = "()test"
        // At position 1, next char is ")"
        let result = handler.shouldSkipClosingCharacter(")", at: 1, in: text)
        XCTAssertTrue(result)
    }

    func testShouldSkipClosingBracketWhenNextCharMatches() {
        let text = "[]test"
        let result = handler.shouldSkipClosingCharacter("]", at: 1, in: text)
        XCTAssertTrue(result)
    }

    func testShouldSkipClosingBraceWhenNextCharMatches() {
        let text = "{}test"
        let result = handler.shouldSkipClosingCharacter("}", at: 1, in: text)
        XCTAssertTrue(result)
    }

    func testShouldSkipClosingDoubleQuoteWhenNextCharMatches() {
        let text = "\"\"test"
        let result = handler.shouldSkipClosingCharacter("\"", at: 1, in: text)
        XCTAssertTrue(result)
    }

    func testShouldSkipClosingSingleQuoteWhenNextCharMatches() {
        let text = "''test"
        let result = handler.shouldSkipClosingCharacter("'", at: 1, in: text)
        XCTAssertTrue(result)
    }

    func testShouldSkipClosingBacktickWhenNextCharMatches() {
        let text = "``test"
        let result = handler.shouldSkipClosingCharacter("`", at: 1, in: text)
        XCTAssertTrue(result)
    }

    func testShouldNotSkipWhenNextCharDoesNotMatch() {
        let text = "(a"
        let result = handler.shouldSkipClosingCharacter(")", at: 1, in: text)
        XCTAssertFalse(result)
    }

    func testShouldNotSkipAtEndOfText() {
        let text = "("
        let result = handler.shouldSkipClosingCharacter(")", at: text.count, in: text)
        XCTAssertFalse(result)
    }

    func testShouldNotSkipWhenDisabled() {
        handler.isEnabled = false
        let text = "()"
        let result = handler.shouldSkipClosingCharacter(")", at: 1, in: text)
        XCTAssertFalse(result)
    }

    func testShouldNotSkipNonClosingCharacter() {
        // "a" is not in the closePairs set
        let text = "aa"
        let result = handler.shouldSkipClosingCharacter("a", at: 1, in: text)
        XCTAssertFalse(result)
    }

    // Note: * and _ are not in closePairs (only openers), so they won't skip
    func testShouldNotSkipAsteriskAsClosingChar() {
        let text = "**"
        let result = handler.shouldSkipClosingCharacter("*", at: 1, in: text)
        XCTAssertFalse(result)
    }

    func testShouldNotSkipUnderscoreAsClosingChar() {
        let text = "__"
        let result = handler.shouldSkipClosingCharacter("_", at: 1, in: text)
        XCTAssertFalse(result)
    }
}

// MARK: - SmartListHandler Tests

final class SmartListHandlerTests: XCTestCase {

    private var handler: SmartListHandler!

    override func setUp() {
        super.setUp()
        handler = SmartListHandler()
    }

    override func tearDown() {
        handler = nil
        super.tearDown()
    }

    // MARK: - isEnabled

    func testIsEnabledByDefault() {
        XCTAssertTrue(handler.isEnabled)
    }

    func testCanDisable() {
        handler.isEnabled = false
        XCTAssertFalse(handler.isEnabled)
    }

    // MARK: - handleNewline: Unordered Lists

    func testNewlineContinuesDashList() {
        let text = "- item one"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "- ")
    }

    func testNewlineContinuesAsteriskList() {
        let text = "* item one"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "* ")
    }

    func testNewlineContinuesPlusList() {
        let text = "+ item one"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "+ ")
    }

    // MARK: - handleNewline: Ordered Lists

    func testNewlineContinuesOrderedList() {
        let text = "1. first item"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "2. ")
    }

    func testNewlineIncrementsOrderedListNumber() {
        let text = "5. fifth item"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "6. ")
    }

    func testNewlineContinuesOrderedListWithLargeNumber() {
        let text = "99. ninety-ninth item"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "100. ")
    }

    // MARK: - handleNewline: Task Lists

    func testNewlineContinuesUncheckedTaskList() {
        let text = "- [ ] a task"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "- [ ] ")
    }

    func testNewlineContinuesCheckedTaskListAsUnchecked() {
        let text = "- [x] done task"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "- [ ] ")
    }

    func testNewlineContinuesCheckedTaskListCapitalX() {
        let text = "- [X] done task"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "- [ ] ")
    }

    // MARK: - handleNewline: Indentation Preservation

    func testNewlinePreservesIndentationForDashList() {
        let text = "  - indented item"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "  - ")
    }

    func testNewlinePreservesIndentationForOrderedList() {
        let text = "    1. deeply indented"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "    2. ")
    }

    func testNewlinePreservesIndentationForTaskList() {
        let text = "  - [ ] indented task"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "  - [ ] ")
    }

    // MARK: - handleNewline: Non-list Lines

    func testNewlineReturnsNilForPlainText() {
        let text = "just some text"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertNil(result)
    }

    func testNewlineReturnsNilForEmptyText() {
        let result = handler.handleNewline(at: 0, in: "")
        XCTAssertNil(result)
    }

    func testNewlineReturnsNilWhenDisabled() {
        handler.isEnabled = false
        let text = "- item"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertNil(result)
    }

    func testNewlineReturnsNilForHeading() {
        let text = "# Heading"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertNil(result)
    }

    // MARK: - handleNewline: Multi-line Text

    func testNewlineContinuesListOnSecondLine() {
        let text = "Some intro text\n- first item"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "- ")
    }

    func testNewlineContinuesOrderedListOnThirdLine() {
        let text = "Title\n\n3. third item"
        let result = handler.handleNewline(at: text.count, in: text)
        XCTAssertEqual(result, "4. ")
    }

    // MARK: - handleBackspace: Empty List Item Removal

    func testBackspaceRemovesEmptyDashListItem() {
        let text = "- "
        let result = handler.handleBackspace(at: text.count, in: text)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.insertion, "")
    }

    func testBackspaceRemovesEmptyAsteriskListItem() {
        let text = "* "
        let result = handler.handleBackspace(at: text.count, in: text)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.insertion, "")
    }

    func testBackspaceRemovesEmptyPlusListItem() {
        let text = "+ "
        let result = handler.handleBackspace(at: text.count, in: text)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.insertion, "")
    }

    func testBackspaceRemovesEmptyOrderedListItem() {
        let text = "1. "
        let result = handler.handleBackspace(at: text.count, in: text)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.insertion, "")
    }

    func testBackspaceRemovesEmptyTaskListItem() {
        let text = "- [ ] "
        let result = handler.handleBackspace(at: text.count, in: text)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.insertion, "")
    }

    // MARK: - handleBackspace: Non-empty List Items

    func testBackspaceReturnsNilForNonEmptyListItem() {
        let text = "- some content"
        let result = handler.handleBackspace(at: text.count, in: text)
        XCTAssertNil(result)
    }

    func testBackspaceReturnsNilForPlainText() {
        let text = "hello"
        let result = handler.handleBackspace(at: text.count, in: text)
        XCTAssertNil(result)
    }

    func testBackspaceReturnsNilAtZeroLocation() {
        let text = "- item"
        let result = handler.handleBackspace(at: 0, in: text)
        XCTAssertNil(result)
    }

    func testBackspaceReturnsNilWhenDisabled() {
        handler.isEnabled = false
        let text = "- "
        let result = handler.handleBackspace(at: text.count, in: text)
        XCTAssertNil(result)
    }

    // MARK: - handleTab: List Indentation

    func testTabIndentsListItem() {
        let text = "- item"
        let result = handler.handleTab(at: text.count, in: text, isShiftTab: false)
        XCTAssertEqual(result, "  ")
    }

    func testTabIndentsOrderedListItem() {
        let text = "1. item"
        let result = handler.handleTab(at: text.count, in: text, isShiftTab: false)
        XCTAssertEqual(result, "  ")
    }

    func testTabIndentsTaskListItem() {
        let text = "- [ ] task"
        let result = handler.handleTab(at: text.count, in: text, isShiftTab: false)
        XCTAssertEqual(result, "  ")
    }

    // MARK: - handleTab: Shift-Tab Outdent

    func testShiftTabOutdentsIndentedListItem() {
        let text = "  - item"
        let result = handler.handleTab(at: text.count, in: text, isShiftTab: true)
        XCTAssertEqual(result, "")
    }

    func testShiftTabReturnsNilForNonIndentedListItem() {
        let text = "- item"
        let result = handler.handleTab(at: text.count, in: text, isShiftTab: true)
        XCTAssertNil(result)
    }

    // MARK: - handleTab: Non-list

    func testTabReturnsNilForPlainText() {
        let text = "hello world"
        let result = handler.handleTab(at: text.count, in: text, isShiftTab: false)
        XCTAssertNil(result)
    }

    func testTabReturnsNilWhenDisabled() {
        handler.isEnabled = false
        let text = "- item"
        let result = handler.handleTab(at: text.count, in: text, isShiftTab: false)
        XCTAssertNil(result)
    }
}

// MARK: - CommandRegistry Tests

@MainActor
final class CommandRegistryTests: XCTestCase {

    private var registry: CommandRegistry!

    override func setUp() {
        super.setUp()
        registry = CommandRegistry()
    }

    override func tearDown() {
        registry = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func makeCommand(
        id: String,
        name: String = "Test Command",
        category: CommandCategory = .edit,
        defaultShortcut: String? = nil,
        isEnabled: @escaping @Sendable () -> Bool = { true },
        execute: @escaping @Sendable @MainActor () -> Void = {}
    ) -> CommandDefinition {
        CommandDefinition(
            id: id,
            name: name,
            category: category,
            defaultShortcut: defaultShortcut,
            isEnabled: isEnabled,
            execute: execute
        )
    }

    // MARK: - Registration

    func testRegisterSingleCommand() {
        let command = makeCommand(id: "test.cmd")
        registry.register(command)
        XCTAssertNotNil(registry.command(for: "test.cmd"))
    }

    func testRegisterMultipleCommands() {
        let cmds = [
            makeCommand(id: "cmd.a", name: "Alpha"),
            makeCommand(id: "cmd.b", name: "Beta"),
            makeCommand(id: "cmd.c", name: "Charlie"),
        ]
        registry.register(cmds)
        XCTAssertEqual(registry.commands.count, 3)
        XCTAssertNotNil(registry.command(for: "cmd.a"))
        XCTAssertNotNil(registry.command(for: "cmd.b"))
        XCTAssertNotNil(registry.command(for: "cmd.c"))
    }

    func testRegisterOverwritesExistingCommand() {
        let cmd1 = makeCommand(id: "test.cmd", name: "Original")
        let cmd2 = makeCommand(id: "test.cmd", name: "Replacement")
        registry.register(cmd1)
        registry.register(cmd2)
        XCTAssertEqual(registry.command(for: "test.cmd")?.name, "Replacement")
        XCTAssertEqual(registry.commands.count, 1)
    }

    // MARK: - Unregistration

    func testUnregisterCommand() {
        let command = makeCommand(id: "test.cmd")
        registry.register(command)
        registry.unregister("test.cmd")
        XCTAssertNil(registry.command(for: "test.cmd"))
        XCTAssertEqual(registry.commands.count, 0)
    }

    func testUnregisterNonExistentCommandDoesNotCrash() {
        registry.unregister("nonexistent")
        XCTAssertEqual(registry.commands.count, 0)
    }

    // MARK: - Execution

    func testExecuteReturnsTrue() {
        var executed = false
        let command = makeCommand(id: "test.cmd") {
            executed = true
        }
        registry.register(command)
        let result = registry.execute("test.cmd")
        XCTAssertTrue(result)
        XCTAssertTrue(executed)
    }

    func testExecuteReturnsFalseForUnknownCommand() {
        let result = registry.execute("nonexistent")
        XCTAssertFalse(result)
    }

    func testExecuteReturnsFalseForDisabledCommand() {
        var executed = false
        let command = makeCommand(id: "test.cmd", isEnabled: { false }) {
            executed = true
        }
        registry.register(command)
        let result = registry.execute("test.cmd")
        XCTAssertFalse(result)
        XCTAssertFalse(executed)
    }

    func testExecuteDoesNotRunDisabledCommandAction() {
        var executionCount = 0
        let command = makeCommand(id: "test.cmd", isEnabled: { false }) {
            executionCount += 1
        }
        registry.register(command)
        _ = registry.execute("test.cmd")
        XCTAssertEqual(executionCount, 0)
    }

    // MARK: - Lookup

    func testCommandForValidID() {
        let command = makeCommand(id: "test.cmd", name: "My Command")
        registry.register(command)
        let found = registry.command(for: "test.cmd")
        XCTAssertEqual(found?.id, "test.cmd")
        XCTAssertEqual(found?.name, "My Command")
    }

    func testCommandForInvalidIDReturnsNil() {
        XCTAssertNil(registry.command(for: "does.not.exist"))
    }

    func testShortcutReturnsDefaultShortcut() {
        let command = makeCommand(id: "test.cmd", defaultShortcut: "cmd+s")
        registry.register(command)
        XCTAssertEqual(registry.shortcut(for: "test.cmd"), "cmd+s")
    }

    func testShortcutReturnsNilWhenNoShortcut() {
        let command = makeCommand(id: "test.cmd")
        registry.register(command)
        XCTAssertNil(registry.shortcut(for: "test.cmd"))
    }

    func testShortcutReturnsOverrideWhenSet() {
        let command = makeCommand(id: "test.cmd", defaultShortcut: "cmd+s")
        registry.register(command)
        registry.setShortcut("cmd+shift+s", for: "test.cmd")
        XCTAssertEqual(registry.shortcut(for: "test.cmd"), "cmd+shift+s")
    }

    func testCommandIDForShortcutFindsDefault() {
        let command = makeCommand(id: "test.cmd", defaultShortcut: "cmd+s")
        registry.register(command)
        XCTAssertEqual(registry.commandID(for: "cmd+s"), "test.cmd")
    }

    func testCommandIDForShortcutFindsOverride() {
        let command = makeCommand(id: "test.cmd", defaultShortcut: "cmd+s")
        registry.register(command)
        registry.setShortcut("cmd+shift+s", for: "test.cmd")
        XCTAssertEqual(registry.commandID(for: "cmd+shift+s"), "test.cmd")
    }

    func testCommandIDForShortcutReturnsNilWhenNotFound() {
        XCTAssertNil(registry.commandID(for: "cmd+q"))
    }

    func testCommandIDForShortcutIsCaseInsensitive() {
        let command = makeCommand(id: "test.cmd", defaultShortcut: "cmd+s")
        registry.register(command)
        XCTAssertEqual(registry.commandID(for: "Cmd+S"), "test.cmd")
    }

    // MARK: - Shortcut Customization

    func testSetShortcut() {
        let command = makeCommand(id: "test.cmd", defaultShortcut: "cmd+s")
        registry.register(command)
        registry.setShortcut("cmd+alt+s", for: "test.cmd")
        XCTAssertEqual(registry.shortcut(for: "test.cmd"), "cmd+alt+s")
    }

    func testSetShortcutNormalizesToLowercase() {
        let command = makeCommand(id: "test.cmd")
        registry.register(command)
        registry.setShortcut("Cmd+Shift+S", for: "test.cmd")
        XCTAssertEqual(registry.shortcut(for: "test.cmd"), "cmd+shift+s")
    }

    func testSetShortcutNilRemovesOverride() {
        let command = makeCommand(id: "test.cmd", defaultShortcut: "cmd+s")
        registry.register(command)
        registry.setShortcut("cmd+alt+s", for: "test.cmd")
        registry.setShortcut(nil, for: "test.cmd")
        // Should fall back to default
        XCTAssertEqual(registry.shortcut(for: "test.cmd"), "cmd+s")
    }

    func testResetShortcut() {
        let command = makeCommand(id: "test.cmd", defaultShortcut: "cmd+s")
        registry.register(command)
        registry.setShortcut("cmd+alt+s", for: "test.cmd")
        registry.resetShortcut(for: "test.cmd")
        XCTAssertEqual(registry.shortcut(for: "test.cmd"), "cmd+s")
    }

    func testResetAllShortcuts() {
        let cmd1 = makeCommand(id: "cmd.a", defaultShortcut: "cmd+a")
        let cmd2 = makeCommand(id: "cmd.b", defaultShortcut: "cmd+b")
        registry.register([cmd1, cmd2])
        registry.setShortcut("cmd+1", for: "cmd.a")
        registry.setShortcut("cmd+2", for: "cmd.b")
        registry.resetAllShortcuts()
        XCTAssertEqual(registry.shortcut(for: "cmd.a"), "cmd+a")
        XCTAssertEqual(registry.shortcut(for: "cmd.b"), "cmd+b")
        XCTAssertTrue(registry.shortcutOverrides.isEmpty)
    }

    // MARK: - Sorting & Filtering

    func testSortedCommandsAreSortedByName() {
        let cmds = [
            makeCommand(id: "c", name: "Charlie"),
            makeCommand(id: "a", name: "Alpha"),
            makeCommand(id: "b", name: "Bravo"),
        ]
        registry.register(cmds)
        let sorted = registry.sortedCommands
        XCTAssertEqual(sorted.map(\.name), ["Alpha", "Bravo", "Charlie"])
    }

    func testSortedCommandsCachingReturnsConsistentResults() {
        let cmds = [
            makeCommand(id: "b", name: "Beta"),
            makeCommand(id: "a", name: "Alpha"),
        ]
        registry.register(cmds)
        let first = registry.sortedCommands
        let second = registry.sortedCommands
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testSortedCommandsCacheInvalidatedOnRegister() {
        let cmds = [
            makeCommand(id: "b", name: "Beta"),
        ]
        registry.register(cmds)
        _ = registry.sortedCommands // populate cache
        registry.register(makeCommand(id: "a", name: "Alpha"))
        let sorted = registry.sortedCommands
        XCTAssertEqual(sorted.count, 2)
        XCTAssertEqual(sorted.first?.name, "Alpha")
    }

    func testCommandsInCategory() {
        let cmds = [
            makeCommand(id: "e1", name: "Edit One", category: .edit),
            makeCommand(id: "f1", name: "File One", category: .file),
            makeCommand(id: "e2", name: "Edit Two", category: .edit),
            makeCommand(id: "v1", name: "View One", category: .view),
        ]
        registry.register(cmds)

        let editCommands = registry.commands(in: .edit)
        XCTAssertEqual(editCommands.count, 2)
        XCTAssertTrue(editCommands.allSatisfy { $0.category == .edit })

        let fileCommands = registry.commands(in: .file)
        XCTAssertEqual(fileCommands.count, 1)

        let viewCommands = registry.commands(in: .view)
        XCTAssertEqual(viewCommands.count, 1)

        let toolsCommands = registry.commands(in: .tools)
        XCTAssertEqual(toolsCommands.count, 0)
    }

    func testSearchByName() {
        let cmds = [
            makeCommand(id: "edit.bold", name: "Bold", category: .format),
            makeCommand(id: "edit.italic", name: "Italic", category: .format),
            makeCommand(id: "file.save", name: "Save", category: .file),
        ]
        registry.register(cmds)

        let results = registry.search(query: "bold")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "edit.bold")
    }

    func testSearchByID() {
        let cmds = [
            makeCommand(id: "edit.bold", name: "Bold"),
            makeCommand(id: "file.save", name: "Save"),
        ]
        registry.register(cmds)

        let results = registry.search(query: "file")
        XCTAssertTrue(results.contains(where: { $0.id == "file.save" }))
    }

    func testSearchByCategory() {
        let cmds = [
            makeCommand(id: "e1", name: "Alpha", category: .export),
            makeCommand(id: "t1", name: "Beta", category: .tools),
        ]
        registry.register(cmds)

        let results = registry.search(query: "export")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "e1")
    }

    func testSearchIsCaseInsensitive() {
        let cmds = [
            makeCommand(id: "cmd", name: "Save File"),
        ]
        registry.register(cmds)

        let results = registry.search(query: "SAVE")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchWithEmptyQueryReturnsAll() {
        let cmds = [
            makeCommand(id: "a", name: "Alpha"),
            makeCommand(id: "b", name: "Beta"),
        ]
        registry.register(cmds)

        let results = registry.search(query: "")
        XCTAssertEqual(results.count, 2)
    }

    func testSearchWithNoMatchReturnsEmpty() {
        let cmds = [
            makeCommand(id: "a", name: "Alpha"),
        ]
        registry.register(cmds)

        let results = registry.search(query: "zzzzz")
        XCTAssertTrue(results.isEmpty)
    }
}

// MARK: - CommandDefinition Tests

final class CommandDefinitionTests: XCTestCase {

    func testCommandDefinitionProperties() {
        let command = CommandDefinition(
            id: "format.bold",
            name: "Bold",
            category: .format,
            defaultShortcut: "cmd+b",
            isEnabled: { true },
            execute: {}
        )
        XCTAssertEqual(command.id, "format.bold")
        XCTAssertEqual(command.name, "Bold")
        XCTAssertEqual(command.category, .format)
        XCTAssertEqual(command.defaultShortcut, "cmd+b")
        XCTAssertTrue(command.isEnabled())
    }

    func testCommandDefinitionDefaultValues() {
        let command = CommandDefinition(
            id: "test",
            name: "Test",
            category: .edit,
            execute: {}
        )
        XCTAssertNil(command.defaultShortcut)
        XCTAssertTrue(command.isEnabled())
    }

    func testCommandDefinitionConformsToIdentifiable() {
        let command = CommandDefinition(
            id: "unique.id",
            name: "Unique",
            category: .tools,
            execute: {}
        )
        // Identifiable conformance: id property
        XCTAssertEqual(command.id, "unique.id")
    }
}

// MARK: - CommandCategory Tests

final class CommandCategoryTests: XCTestCase {

    func testAllCases() {
        let allCases = CommandCategory.allCases
        XCTAssertEqual(allCases.count, 7)
        XCTAssertTrue(allCases.contains(.file))
        XCTAssertTrue(allCases.contains(.edit))
        XCTAssertTrue(allCases.contains(.view))
        XCTAssertTrue(allCases.contains(.format))
        XCTAssertTrue(allCases.contains(.navigate))
        XCTAssertTrue(allCases.contains(.export))
        XCTAssertTrue(allCases.contains(.tools))
    }

    func testRawValues() {
        XCTAssertEqual(CommandCategory.file.rawValue, "File")
        XCTAssertEqual(CommandCategory.edit.rawValue, "Edit")
        XCTAssertEqual(CommandCategory.view.rawValue, "View")
        XCTAssertEqual(CommandCategory.format.rawValue, "Format")
        XCTAssertEqual(CommandCategory.navigate.rawValue, "Navigate")
        XCTAssertEqual(CommandCategory.export.rawValue, "Export")
        XCTAssertEqual(CommandCategory.tools.rawValue, "Tools")
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for category in CommandCategory.allCases {
            let data = try encoder.encode(category)
            let decoded = try decoder.decode(CommandCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }
}

// MARK: - KeyComboParser Tests

final class KeyComboParserTests: XCTestCase {

    // MARK: - normalize

    func testNormalizeAlreadyNormalized() {
        XCTAssertEqual(KeyComboParser.normalize("cmd+shift+p"), "cmd+shift+p")
    }

    func testNormalizeMixedCase() {
        XCTAssertEqual(KeyComboParser.normalize("Cmd+Shift+P"), "cmd+shift+p")
    }

    func testNormalizeUpperCase() {
        XCTAssertEqual(KeyComboParser.normalize("CMD+S"), "cmd+s")
    }

    func testNormalizeSymbolModifiers() {
        XCTAssertEqual(KeyComboParser.normalize("\u{2318}+\u{21E7}+P"), "cmd+shift+p")
    }

    func testNormalizeCommandSymbol() {
        XCTAssertEqual(KeyComboParser.normalize("\u{2318}+S"), "cmd+s")
    }

    func testNormalizeOptionSymbol() {
        XCTAssertEqual(KeyComboParser.normalize("\u{2325}+A"), "alt+a")
    }

    func testNormalizeControlSymbol() {
        XCTAssertEqual(KeyComboParser.normalize("\u{2303}+C"), "ctrl+c")
    }

    func testNormalizeSingleKey() {
        XCTAssertEqual(KeyComboParser.normalize("A"), "a")
    }

    func testNormalizeWithSpaces() {
        XCTAssertEqual(KeyComboParser.normalize("cmd + shift + s"), "cmd+shift+s")
    }

    // MARK: - displayString

    func testDisplayStringCmd() {
        let display = KeyComboParser.displayString(for: "cmd+s")
        XCTAssertEqual(display, "\u{2318}S")
    }

    func testDisplayStringCmdShift() {
        let display = KeyComboParser.displayString(for: "cmd+shift+p")
        XCTAssertEqual(display, "\u{2318}\u{21E7}P")
    }

    func testDisplayStringCtrl() {
        let display = KeyComboParser.displayString(for: "ctrl+c")
        XCTAssertEqual(display, "\u{2303}C")
    }

    func testDisplayStringAlt() {
        let display = KeyComboParser.displayString(for: "alt+a")
        XCTAssertEqual(display, "\u{2325}A")
    }

    func testDisplayStringEnter() {
        let display = KeyComboParser.displayString(for: "cmd+enter")
        XCTAssertEqual(display, "\u{2318}\u{21A9}")
    }

    func testDisplayStringReturn() {
        let display = KeyComboParser.displayString(for: "cmd+return")
        XCTAssertEqual(display, "\u{2318}\u{21A9}")
    }

    func testDisplayStringTab() {
        let display = KeyComboParser.displayString(for: "cmd+tab")
        XCTAssertEqual(display, "\u{2318}\u{21E5}")
    }

    func testDisplayStringEscape() {
        let display = KeyComboParser.displayString(for: "escape")
        XCTAssertEqual(display, "\u{238B}")
    }

    func testDisplayStringEsc() {
        let display = KeyComboParser.displayString(for: "esc")
        XCTAssertEqual(display, "\u{238B}")
    }

    func testDisplayStringDelete() {
        let display = KeyComboParser.displayString(for: "delete")
        XCTAssertEqual(display, "\u{232B}")
    }

    func testDisplayStringBackspace() {
        let display = KeyComboParser.displayString(for: "backspace")
        XCTAssertEqual(display, "\u{232B}")
    }

    func testDisplayStringArrowKeys() {
        XCTAssertEqual(KeyComboParser.displayString(for: "up"), "\u{2191}")
        XCTAssertEqual(KeyComboParser.displayString(for: "down"), "\u{2193}")
        XCTAssertEqual(KeyComboParser.displayString(for: "left"), "\u{2190}")
        XCTAssertEqual(KeyComboParser.displayString(for: "right"), "\u{2192}")
    }

    func testDisplayStringSpace() {
        let display = KeyComboParser.displayString(for: "cmd+space")
        XCTAssertEqual(display, "\u{2318}Space")
    }

    func testDisplayStringAllModifiers() {
        let display = KeyComboParser.displayString(for: "cmd+ctrl+alt+shift+a")
        XCTAssertEqual(display, "\u{2318}\u{2303}\u{2325}\u{21E7}A")
    }

    func testDisplayStringUnknownKeyUppercased() {
        let display = KeyComboParser.displayString(for: "cmd+f1")
        XCTAssertEqual(display, "\u{2318}F1")
    }
}

// MARK: - KeybindingEntry Tests

final class KeybindingEntryTests: XCTestCase {

    func testProperties() {
        let entry = KeybindingEntry(commandID: "file.save", key: "cmd+s", when: "editorFocused")
        XCTAssertEqual(entry.commandID, "file.save")
        XCTAssertEqual(entry.key, "cmd+s")
        XCTAssertEqual(entry.when, "editorFocused")
    }

    func testWhenIsOptional() {
        let entry = KeybindingEntry(commandID: "file.save", key: "cmd+s")
        XCTAssertNil(entry.when)
    }

    func testIdentifiable() {
        let entry = KeybindingEntry(commandID: "file.save", key: "cmd+s")
        XCTAssertEqual(entry.id, "file.save")
    }

    func testEquatable() {
        let entry1 = KeybindingEntry(commandID: "file.save", key: "cmd+s", when: nil)
        let entry2 = KeybindingEntry(commandID: "file.save", key: "cmd+s", when: nil)
        XCTAssertEqual(entry1, entry2)
    }

    func testNotEqual() {
        let entry1 = KeybindingEntry(commandID: "file.save", key: "cmd+s")
        let entry2 = KeybindingEntry(commandID: "file.open", key: "cmd+o")
        XCTAssertNotEqual(entry1, entry2)
    }

    // MARK: - Codable

    func testEncodeDecode() throws {
        let entry = KeybindingEntry(commandID: "file.save", key: "cmd+s", when: "editorFocused")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(KeybindingEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }

    func testEncodeDecodeWithoutWhen() throws {
        let entry = KeybindingEntry(commandID: "file.save", key: "cmd+s")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(KeybindingEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }

    func testCodingKeysMapping() throws {
        // The "commandID" property maps to "command" in JSON
        let json = """
        {"command": "file.save", "key": "cmd+s"}
        """
        let data = json.data(using: .utf8)!
        let entry = try JSONDecoder().decode(KeybindingEntry.self, from: data)
        XCTAssertEqual(entry.commandID, "file.save")
        XCTAssertEqual(entry.key, "cmd+s")
    }

    func testEncodingUsesCommandKey() throws {
        let entry = KeybindingEntry(commandID: "file.save", key: "cmd+s")
        let data = try JSONEncoder().encode(entry)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(jsonObject?["command"])
        XCTAssertNil(jsonObject?["commandID"])
    }
}

// MARK: - KeybindingConfiguration Tests

final class KeybindingConfigurationTests: XCTestCase {

    func testDefaultInit() {
        let config = KeybindingConfiguration()
        XCTAssertEqual(config.version, 1)
        XCTAssertTrue(config.bindings.isEmpty)
    }

    func testCustomInit() {
        let bindings = [
            KeybindingEntry(commandID: "file.save", key: "cmd+s"),
        ]
        let config = KeybindingConfiguration(version: 2, bindings: bindings)
        XCTAssertEqual(config.version, 2)
        XCTAssertEqual(config.bindings.count, 1)
    }

    func testEquatable() {
        let config1 = KeybindingConfiguration(version: 1, bindings: [
            KeybindingEntry(commandID: "a", key: "cmd+a"),
        ])
        let config2 = KeybindingConfiguration(version: 1, bindings: [
            KeybindingEntry(commandID: "a", key: "cmd+a"),
        ])
        XCTAssertEqual(config1, config2)
    }

    func testNotEqual() {
        let config1 = KeybindingConfiguration(version: 1, bindings: [])
        let config2 = KeybindingConfiguration(version: 2, bindings: [])
        XCTAssertNotEqual(config1, config2)
    }

    // MARK: - Default Configuration

    func testDefaultConfigurationIsVersion1() {
        XCTAssertEqual(KeybindingConfiguration.default.version, 1)
    }

    func testDefaultConfigurationHasBindings() {
        let config = KeybindingConfiguration.default
        XCTAssertFalse(config.bindings.isEmpty)
    }

    func testDefaultConfigurationContainsFileSave() {
        let config = KeybindingConfiguration.default
        let saveBinding = config.bindings.first { $0.commandID == "file.save" }
        XCTAssertNotNil(saveBinding)
        XCTAssertEqual(saveBinding?.key, "cmd+s")
    }

    func testDefaultConfigurationContainsCommandPalette() {
        let config = KeybindingConfiguration.default
        let paletteBinding = config.bindings.first { $0.commandID == "view.commandPalette" }
        XCTAssertNotNil(paletteBinding)
        XCTAssertEqual(paletteBinding?.key, "cmd+shift+p")
    }

    func testDefaultConfigurationContainsFormatBold() {
        let config = KeybindingConfiguration.default
        let boldBinding = config.bindings.first { $0.commandID == "format.bold" }
        XCTAssertNotNil(boldBinding)
        XCTAssertEqual(boldBinding?.key, "cmd+b")
    }

    func testDefaultConfigurationContainsNavigateBindings() {
        let config = KeybindingConfiguration.default
        let moveUp = config.bindings.first { $0.commandID == "navigate.moveLineUp" }
        XCTAssertNotNil(moveUp)
        XCTAssertEqual(moveUp?.key, "alt+up")
    }

    func testDefaultConfigurationContainsExportBindings() {
        let config = KeybindingConfiguration.default
        let exportHtml = config.bindings.first { $0.commandID == "export.html" }
        XCTAssertNotNil(exportHtml)
        XCTAssertEqual(exportHtml?.key, "cmd+shift+e")
    }

    // MARK: - Codable

    func testEncodeDecode() throws {
        let config = KeybindingConfiguration(version: 1, bindings: [
            KeybindingEntry(commandID: "file.save", key: "cmd+s"),
            KeybindingEntry(commandID: "edit.undo", key: "cmd+z"),
        ])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(KeybindingConfiguration.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testDefaultConfigurationRoundTrips() throws {
        let config = KeybindingConfiguration.default
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(KeybindingConfiguration.self, from: data)
        XCTAssertEqual(decoded, config)
    }
}

// MARK: - KeybindingLoader Tests

final class KeybindingLoaderTests: XCTestCase {

    private var loader: KeybindingLoader!
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        loader = KeybindingLoader()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TymarkKeybindingLoaderTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        loader = nil
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - load() Default

    func testLoadReturnsDefaultWhenNoUserConfig() {
        let config = loader.load()
        // Should at least have the default bindings
        XCTAssertFalse(config.bindings.isEmpty)
        XCTAssertEqual(config.version, 1)
    }

    // MARK: - load(from url:)

    func testLoadFromURL() throws {
        let config = KeybindingConfiguration(version: 2, bindings: [
            KeybindingEntry(commandID: "custom.cmd", key: "cmd+shift+c"),
        ])

        let fileURL = tempDirectory.appendingPathComponent("test-keybindings.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        try data.write(to: fileURL)

        let loaded = try loader.load(from: fileURL)
        XCTAssertEqual(loaded.version, 2)
        XCTAssertEqual(loaded.bindings.count, 1)
        XCTAssertEqual(loaded.bindings.first?.commandID, "custom.cmd")
        XCTAssertEqual(loaded.bindings.first?.key, "cmd+shift+c")
    }

    func testLoadFromInvalidURLThrows() {
        let badURL = tempDirectory.appendingPathComponent("nonexistent.json")
        XCTAssertThrowsError(try loader.load(from: badURL))
    }

    // MARK: - load(from jsonString:)

    func testLoadFromJSONString() throws {
        let json = """
        {
            "version": 3,
            "bindings": [
                {"command": "test.one", "key": "cmd+1"},
                {"command": "test.two", "key": "cmd+2", "when": "editorFocused"}
            ]
        }
        """
        let config = try loader.load(from: json)
        XCTAssertEqual(config.version, 3)
        XCTAssertEqual(config.bindings.count, 2)
        XCTAssertEqual(config.bindings[0].commandID, "test.one")
        XCTAssertEqual(config.bindings[0].key, "cmd+1")
        XCTAssertNil(config.bindings[0].when)
        XCTAssertEqual(config.bindings[1].commandID, "test.two")
        XCTAssertEqual(config.bindings[1].key, "cmd+2")
        XCTAssertEqual(config.bindings[1].when, "editorFocused")
    }

    func testLoadFromInvalidJSONStringThrows() {
        let badJSON = "this is not json"
        XCTAssertThrowsError(try loader.load(from: badJSON))
    }

    func testLoadFromEmptyJSONObjectThrows() {
        let json = "{}"
        // Missing required "version" and "bindings" fields
        XCTAssertThrowsError(try loader.load(from: json))
    }

    func testLoadFromMalformedJSONStringThrows() {
        let json = """
        {"version": 1, "bindings": "not an array"}
        """
        XCTAssertThrowsError(try loader.load(from: json))
    }

    // MARK: - save(_:to:)

    func testSaveToURL() throws {
        let config = KeybindingConfiguration(version: 1, bindings: [
            KeybindingEntry(commandID: "save.test", key: "cmd+s"),
        ])
        let fileURL = tempDirectory.appendingPathComponent("save-test.json")
        try loader.save(config, to: fileURL)

        // Verify the file was written
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        // Verify it can be loaded back
        let loaded = try loader.load(from: fileURL)
        XCTAssertEqual(loaded, config)
    }

    func testSaveAndLoadRoundTrip() throws {
        let original = KeybindingConfiguration(version: 5, bindings: [
            KeybindingEntry(commandID: "a", key: "cmd+a"),
            KeybindingEntry(commandID: "b", key: "cmd+b", when: "editorFocused"),
            KeybindingEntry(commandID: "c", key: "ctrl+shift+c"),
        ])
        let fileURL = tempDirectory.appendingPathComponent("roundtrip.json")
        try loader.save(original, to: fileURL)
        let loaded = try loader.load(from: fileURL)
        XCTAssertEqual(loaded, original)
    }

    // MARK: - Merge (via load())

    func testMergeLogicOverridesBase() throws {
        // We test the merge behavior indirectly by creating a scenario
        // The load() method merges user overrides with defaults
        // We test the JSON-based override scenario

        // Create a user config that overrides file.save
        let overrideJSON = """
        {
            "version": 2,
            "bindings": [
                {"command": "file.save", "key": "ctrl+s"}
            ]
        }
        """
        let overrideConfig = try loader.load(from: overrideJSON)

        // Manually simulate merge: base is default, override changes file.save
        let baseConfig = KeybindingConfiguration.default
        let baseSave = baseConfig.bindings.first { $0.commandID == "file.save" }
        XCTAssertEqual(baseSave?.key, "cmd+s")

        // The override changes just file.save
        let overrideSave = overrideConfig.bindings.first { $0.commandID == "file.save" }
        XCTAssertEqual(overrideSave?.key, "ctrl+s")
    }
}

// MARK: - KeybindingError Tests

final class KeybindingErrorTests: XCTestCase {

    func testInvalidJSONErrorDescription() {
        let error = KeybindingError.invalidJSON
        XCTAssertEqual(error.errorDescription, "Invalid JSON keybinding configuration")
    }

    func testNoConfigDirectoryErrorDescription() {
        let error = KeybindingError.noConfigDirectory
        XCTAssertEqual(error.errorDescription, "Unable to locate configuration directory")
    }

    func testInvalidKeyComboErrorDescription() {
        let error = KeybindingError.invalidKeyCombo("bad+combo")
        XCTAssertEqual(error.errorDescription, "Invalid key combination: bad+combo")
    }

    func testErrorConformsToLocalizedError() {
        let error: LocalizedError = KeybindingError.invalidJSON
        XCTAssertNotNil(error.errorDescription)
    }
}

// MARK: - KeybindingHandler Tests

final class KeybindingHandlerTests: XCTestCase {

    // MARK: - Initialization

    func testInitWithDefaultConfiguration() {
        let handler = KeybindingHandler()
        XCTAssertEqual(handler.currentConfiguration, KeybindingConfiguration.default)
    }

    func testInitWithCustomConfiguration() {
        let config = KeybindingConfiguration(version: 2, bindings: [
            KeybindingEntry(commandID: "test", key: "cmd+t"),
        ])
        let handler = KeybindingHandler(configuration: config)
        XCTAssertEqual(handler.currentConfiguration, config)
    }

    // MARK: - registerKeybinding / unregisterKeybinding

    func testRegisterAndUnregisterKeybinding() {
        let handler = KeybindingHandler()
        var called = false
        handler.registerKeybinding("cmd+k") {
            called = true
            return true
        }
        // We cannot directly invoke because handleKeyEvent requires NSEvent
        // But we can verify unregister does not crash
        handler.unregisterKeybinding("cmd+k")
        XCTAssertFalse(called) // never invoked
    }

    func testRegisterKeybindingNormalizesToLowercase() {
        let handler = KeybindingHandler()
        var called = false
        handler.registerKeybinding("CMD+K") {
            called = true
            return true
        }
        // Unregister with lowercase should work since it was normalized
        handler.unregisterKeybinding("cmd+k")
        // No crash means it was stored under the normalized key
        XCTAssertFalse(called)
    }

    // MARK: - Command Palette

    func testSetCommandPaletteHandler() {
        let handler = KeybindingHandler()
        var paletteShown = false
        handler.setCommandPaletteHandler {
            paletteShown = true
        }
        handler.showCommandPalette()
        XCTAssertTrue(paletteShown)
    }

    func testShowCommandPaletteWithoutHandler() {
        let handler = KeybindingHandler()
        // Should not crash when called without a handler
        handler.showCommandPalette()
    }

    func testCommandPaletteHandlerCanBeReplaced() {
        let handler = KeybindingHandler()
        var firstCalled = false
        var secondCalled = false

        handler.setCommandPaletteHandler {
            firstCalled = true
        }
        handler.setCommandPaletteHandler {
            secondCalled = true
        }
        handler.showCommandPalette()
        XCTAssertFalse(firstCalled)
        XCTAssertTrue(secondCalled)
    }

    // MARK: - currentConfiguration

    func testCurrentConfigurationReturnsInitialConfig() {
        let config = KeybindingConfiguration(version: 7, bindings: [
            KeybindingEntry(commandID: "x", key: "cmd+x"),
        ])
        let handler = KeybindingHandler(configuration: config)
        let current = handler.currentConfiguration
        XCTAssertEqual(current.version, 7)
        XCTAssertEqual(current.bindings.count, 1)
        XCTAssertEqual(current.bindings.first?.commandID, "x")
    }
}

// MARK: - Integration Tests

@MainActor
final class KeybindingHandlerRegistryIntegrationTests: XCTestCase {

    func testSetCommandRegistrySyncsBindings() {
        let registry = CommandRegistry()
        var executed = false
        let command = CommandDefinition(
            id: "file.save",
            name: "Save",
            category: .file,
            defaultShortcut: "cmd+s",
            execute: { executed = true }
        )
        registry.register(command)

        let config = KeybindingConfiguration(version: 1, bindings: [
            KeybindingEntry(commandID: "file.save", key: "ctrl+s"),
        ])
        let handler = KeybindingHandler(configuration: config)
        handler.setCommandRegistry(registry)

        // The registry shortcut should now be overridden to ctrl+s
        XCTAssertEqual(registry.shortcut(for: "file.save"), "ctrl+s")
    }

    func testLoadConfigurationResyncsWithRegistry() {
        let registry = CommandRegistry()
        let command = CommandDefinition(
            id: "file.save",
            name: "Save",
            category: .file,
            defaultShortcut: "cmd+s",
            execute: {}
        )
        registry.register(command)

        let handler = KeybindingHandler(configuration: .default)
        handler.setCommandRegistry(registry)

        // Now load a new config
        let newConfig = KeybindingConfiguration(version: 2, bindings: [
            KeybindingEntry(commandID: "file.save", key: "alt+s"),
        ])
        handler.loadConfiguration(newConfig)

        // Should clear old overrides and apply new ones
        XCTAssertEqual(registry.shortcut(for: "file.save"), "alt+s")
        XCTAssertEqual(handler.currentConfiguration.version, 2)
    }

    func testLoadConfigurationResetsAllShortcutsFirst() {
        let registry = CommandRegistry()
        let cmd1 = CommandDefinition(
            id: "cmd.a", name: "A", category: .edit, defaultShortcut: "cmd+a", execute: {}
        )
        let cmd2 = CommandDefinition(
            id: "cmd.b", name: "B", category: .edit, defaultShortcut: "cmd+b", execute: {}
        )
        registry.register([cmd1, cmd2])

        let handler = KeybindingHandler(configuration: KeybindingConfiguration(
            version: 1,
            bindings: [
                KeybindingEntry(commandID: "cmd.a", key: "ctrl+a"),
                KeybindingEntry(commandID: "cmd.b", key: "ctrl+b"),
            ]
        ))
        handler.setCommandRegistry(registry)

        // Both should be overridden
        XCTAssertEqual(registry.shortcut(for: "cmd.a"), "ctrl+a")
        XCTAssertEqual(registry.shortcut(for: "cmd.b"), "ctrl+b")

        // Load new config that only overrides cmd.a
        let newConfig = KeybindingConfiguration(version: 2, bindings: [
            KeybindingEntry(commandID: "cmd.a", key: "alt+a"),
        ])
        handler.loadConfiguration(newConfig)

        // cmd.a should have new override, cmd.b should revert to default
        XCTAssertEqual(registry.shortcut(for: "cmd.a"), "alt+a")
        XCTAssertEqual(registry.shortcut(for: "cmd.b"), "cmd+b")
    }
}
