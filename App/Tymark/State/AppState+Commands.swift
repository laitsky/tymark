import AppKit
import TymarkEditor
import TymarkAI

@MainActor
extension AppState {
    // MARK: - Command Registration

    func registerCommands() {
        commandRegistry.register([
            // File commands
            CommandDefinition(
                id: "file.new",
                name: "New Document",
                category: .file,
                defaultShortcut: "cmd+n"
            ) { [weak self] in
                self?.sendAppAction("newDocument:")
            },

            CommandDefinition(
                id: "file.open",
                name: "Open Document",
                category: .file,
                defaultShortcut: "cmd+o"
            ) { [weak self] in
                self?.openDocument()
            },

            CommandDefinition(
                id: "file.save",
                name: "Save",
                category: .file,
                defaultShortcut: "cmd+s"
            ) { [weak self] in
                self?.sendAppAction("saveDocument:")
            },

            CommandDefinition(
                id: "file.saveAs",
                name: "Save As...",
                category: .file,
                defaultShortcut: "cmd+shift+s"
            ) { [weak self] in
                self?.sendAppAction("saveDocumentAs:")
            },

            CommandDefinition(
                id: "file.close",
                name: "Close",
                category: .file,
                defaultShortcut: "cmd+w"
            ) { [weak self] in
                self?.sendAppAction("performClose:")
            },

            // Edit commands
            CommandDefinition(
                id: "edit.undo",
                name: "Undo",
                category: .edit,
                defaultShortcut: "cmd+z"
            ) { [weak self] in
                self?.sendAppAction("undo:")
            },

            CommandDefinition(
                id: "edit.redo",
                name: "Redo",
                category: .edit,
                defaultShortcut: "cmd+shift+z"
            ) { [weak self] in
                self?.sendAppAction("redo:")
            },

            CommandDefinition(
                id: "edit.cut",
                name: "Cut",
                category: .edit,
                defaultShortcut: "cmd+x"
            ) { [weak self] in
                self?.sendAppAction("cut:")
            },

            CommandDefinition(
                id: "edit.copy",
                name: "Copy",
                category: .edit,
                defaultShortcut: "cmd+c"
            ) { [weak self] in
                self?.sendAppAction("copy:")
            },

            CommandDefinition(
                id: "edit.paste",
                name: "Paste",
                category: .edit,
                defaultShortcut: "cmd+v"
            ) { [weak self] in
                self?.sendAppAction("paste:")
            },

            CommandDefinition(
                id: "edit.selectAll",
                name: "Select All",
                category: .edit,
                defaultShortcut: "cmd+a"
            ) { [weak self] in
                self?.sendAppAction("selectAll:")
            },

            CommandDefinition(
                id: "edit.addNextOccurrence",
                name: "Add Next Occurrence",
                category: .edit,
                defaultShortcut: "cmd+d"
            ) { [weak self] in
                self?.activeTextManipulator?.addNextSelectionOccurrence()
            },

            CommandDefinition(
                id: "edit.selectAllOccurrences",
                name: "Select All Occurrences",
                category: .edit,
                defaultShortcut: "cmd+shift+l"
            ) { [weak self] in
                self?.activeTextManipulator?.selectAllSelectionOccurrences()
            },

            // View commands
            CommandDefinition(
                id: "view.commandPalette",
                name: "Command Palette",
                category: .view,
                defaultShortcut: "cmd+shift+p"
            ) { [weak self] in
                self?.isCommandPaletteVisible.toggle()
            },

            CommandDefinition(
                id: "view.quickOpen",
                name: "Quick Open",
                category: .view,
                defaultShortcut: "cmd+p"
            ) { [weak self] in
                self?.isQuickOpenVisible = true
            },

            CommandDefinition(
                id: "view.toggleSidebar",
                name: "Toggle Sidebar",
                category: .view,
                defaultShortcut: "cmd+shift+b"
            ) { [weak self] in
                self?.isSidebarVisible.toggle()
            },

            CommandDefinition(
                id: "view.toggleFocusMode",
                name: "Toggle Focus Mode",
                category: .view,
                defaultShortcut: "cmd+shift+f"
            ) { [weak self] in
                self?.isFocusModeEnabled.toggle()
            },

            CommandDefinition(
                id: "view.toggleTypewriterMode",
                name: "Toggle Typewriter Mode",
                category: .view,
                defaultShortcut: "cmd+shift+t"
            ) { [weak self] in
                guard let self else { return }
                self.isTypewriterModeEnabled.toggle()
                UserDefaults.standard.set(self.isTypewriterModeEnabled, forKey: "enableTypewriterMode")
            },

            CommandDefinition(
                id: "view.toggleSourceMode",
                name: "Toggle Source Mode",
                category: .view,
                defaultShortcut: "cmd+/"
            ) { [weak self] in
                // Source mode toggled via EditorViewModel in ContentView
                self?.sourceModeShouldToggle = true
            },

            CommandDefinition(
                id: "view.modeEditor",
                name: "View: Editor Only",
                category: .view,
                defaultShortcut: "cmd+alt+1"
            ) { [weak self] in
                self?.workspaceViewMode = .editor
            },

            CommandDefinition(
                id: "view.modeSplit",
                name: "View: Split",
                category: .view,
                defaultShortcut: "cmd+alt+2"
            ) { [weak self] in
                self?.workspaceViewMode = .split
            },

            CommandDefinition(
                id: "view.modePreview",
                name: "View: Preview Only",
                category: .view,
                defaultShortcut: "cmd+alt+3"
            ) { [weak self] in
                self?.workspaceViewMode = .preview
            },

            CommandDefinition(
                id: "view.toggleInspector",
                name: "Toggle Inspector",
                category: .view,
                defaultShortcut: "cmd+shift+i"
            ) { [weak self] in
                self?.isInspectorVisible.toggle()
            },

            CommandDefinition(
                id: "view.zoomIn",
                name: "Zoom In",
                category: .view,
                defaultShortcut: "cmd+="
            ) { [weak self] in
                self?.activeTextManipulator?.zoomIn()
            },

            CommandDefinition(
                id: "view.zoomOut",
                name: "Zoom Out",
                category: .view,
                defaultShortcut: "cmd+-"
            ) { [weak self] in
                self?.activeTextManipulator?.zoomOut()
            },

            CommandDefinition(
                id: "view.resetZoom",
                name: "Reset Zoom",
                category: .view,
                defaultShortcut: "cmd+0"
            ) { [weak self] in
                self?.activeTextManipulator?.resetZoom()
            },

            // Format commands
            CommandDefinition(
                id: "format.bold",
                name: "Bold",
                category: .format,
                defaultShortcut: "cmd+b"
            ) { [weak self] in
                self?.activeTextManipulator?.wrapSelection(prefix: "**", suffix: "**")
            },

            CommandDefinition(
                id: "format.italic",
                name: "Italic",
                category: .format,
                defaultShortcut: "cmd+i"
            ) { [weak self] in
                self?.activeTextManipulator?.wrapSelection(prefix: "*", suffix: "*")
            },

            CommandDefinition(
                id: "format.strikethrough",
                name: "Strikethrough",
                category: .format,
                defaultShortcut: "cmd+shift+x"
            ) { [weak self] in
                self?.activeTextManipulator?.wrapSelection(prefix: "~~", suffix: "~~")
            },

            CommandDefinition(
                id: "format.inlineCode",
                name: "Inline Code",
                category: .format,
                defaultShortcut: "cmd+e"
            ) { [weak self] in
                self?.activeTextManipulator?.wrapSelection(prefix: "`", suffix: "`")
            },

            CommandDefinition(
                id: "format.link",
                name: "Insert Link",
                category: .format,
                defaultShortcut: "cmd+k"
            ) { [weak self] in
                self?.activeTextManipulator?.insertLink(url: "https://")
            },

            CommandDefinition(
                id: "format.heading1",
                name: "Heading 1",
                category: .format,
                defaultShortcut: "cmd+1"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("# ")
            },

            CommandDefinition(
                id: "format.heading2",
                name: "Heading 2",
                category: .format,
                defaultShortcut: "cmd+2"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("## ")
            },

            CommandDefinition(
                id: "format.heading3",
                name: "Heading 3",
                category: .format,
                defaultShortcut: "cmd+3"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("### ")
            },

            CommandDefinition(
                id: "format.heading4",
                name: "Heading 4",
                category: .format,
                defaultShortcut: "cmd+4"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("#### ")
            },

            CommandDefinition(
                id: "format.heading5",
                name: "Heading 5",
                category: .format,
                defaultShortcut: "cmd+5"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("##### ")
            },

            CommandDefinition(
                id: "format.heading6",
                name: "Heading 6",
                category: .format,
                defaultShortcut: "cmd+6"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("###### ")
            },

            CommandDefinition(
                id: "format.orderedList",
                name: "Ordered List",
                category: .format,
                defaultShortcut: "cmd+shift+7"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("1. ")
            },

            CommandDefinition(
                id: "format.unorderedList",
                name: "Unordered List",
                category: .format,
                defaultShortcut: "cmd+shift+8"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("- ")
            },

            CommandDefinition(
                id: "format.taskList",
                name: "Task List",
                category: .format,
                defaultShortcut: "cmd+shift+9"
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("- [ ] ")
            },

            CommandDefinition(
                id: "format.blockquote",
                name: "Blockquote",
                category: .format,
                defaultShortcut: "cmd+shift+."
            ) { [weak self] in
                self?.activeTextManipulator?.toggleLinePrefix("> ")
            },

            CommandDefinition(
                id: "format.codeBlock",
                name: "Code Block",
                category: .format,
                defaultShortcut: "cmd+shift+c"
            ) { [weak self] in
                self?.activeTextManipulator?.insertAtCursor("\n```\n\n```\n")
            },

            CommandDefinition(
                id: "format.insertTable",
                name: "Insert Table",
                category: .format,
                defaultShortcut: "cmd+alt+t"
            ) { [weak self] in
                self?.activeTextManipulator?.insertAtCursor(
                    """
                    | Column 1 | Column 2 |
                    | --- | --- |
                    |  |  |
                    """
                )
            },

            CommandDefinition(
                id: "format.tableAddRow",
                name: "Table: Add Row Below",
                category: .format
            ) { [weak self] in
                self?.activeTextManipulator?.addTableRowBelow()
            },

            CommandDefinition(
                id: "format.tableAddColumn",
                name: "Table: Add Column",
                category: .format
            ) { [weak self] in
                self?.activeTextManipulator?.addTableColumnAfter()
            },

            CommandDefinition(
                id: "format.tableCycleAlignment",
                name: "Table: Cycle Column Alignment",
                category: .format
            ) { [weak self] in
                self?.activeTextManipulator?.cycleTableColumnAlignment()
            },

            CommandDefinition(
                id: "format.horizontalRule",
                name: "Horizontal Rule",
                category: .format,
                defaultShortcut: "cmd+shift+-"
            ) { [weak self] in
                self?.activeTextManipulator?.insertAtCursor("\n---\n")
            },

            // Navigate commands
            CommandDefinition(
                id: "navigate.moveLineUp",
                name: "Move Line Up",
                category: .navigate,
                defaultShortcut: "alt+up"
            ) { [weak self] in
                self?.activeTextManipulator?.moveLineUp()
            },

            CommandDefinition(
                id: "navigate.moveLineDown",
                name: "Move Line Down",
                category: .navigate,
                defaultShortcut: "alt+down"
            ) { [weak self] in
                self?.activeTextManipulator?.moveLineDown()
            },

            CommandDefinition(
                id: "navigate.duplicateLine",
                name: "Duplicate Line",
                category: .navigate,
                defaultShortcut: "cmd+shift+d"
            ) { [weak self] in
                self?.activeTextManipulator?.duplicateLine()
            },

            // Export commands
            CommandDefinition(
                id: "export.html",
                name: "Export as HTML",
                category: .export,
                defaultShortcut: "cmd+shift+e"
            ) { [weak self] in
                self?.pendingExportFormat = "html"
            },

            CommandDefinition(
                id: "export.pdf",
                name: "Export as PDF",
                category: .export,
                defaultShortcut: "cmd+alt+p"
            ) { [weak self] in
                self?.pendingExportFormat = "pdf"
            },

            CommandDefinition(
                id: "export.docx",
                name: "Export as Word",
                category: .export
            ) { [weak self] in
                self?.pendingExportFormat = "docx"
            },

            CommandDefinition(
                id: "export.rtf",
                name: "Export as RTF",
                category: .export
            ) { [weak self] in
                self?.pendingExportFormat = "rtf"
            },

            // Phase 6: Find & Replace commands
            CommandDefinition(
                id: "edit.find",
                name: "Find",
                category: .edit,
                defaultShortcut: "cmd+f"
            ) { [weak self] in
                self?.isFindBarVisible = true
            },

            CommandDefinition(
                id: "edit.findAndReplace",
                name: "Find and Replace",
                category: .edit,
                defaultShortcut: "cmd+h"
            ) { [weak self] in
                self?.isFindBarVisible = true
            },

            CommandDefinition(
                id: "edit.findNext",
                name: "Find Next",
                category: .edit,
                defaultShortcut: "cmd+g"
            ) { [weak self] in
                if let textView = self?.activeTextManipulator as? TymarkTextView {
                    textView.findReplaceEngine.findNext()
                }
            },

            CommandDefinition(
                id: "edit.findPrevious",
                name: "Find Previous",
                category: .edit,
                defaultShortcut: "cmd+shift+g"
            ) { [weak self] in
                if let textView = self?.activeTextManipulator as? TymarkTextView {
                    textView.findReplaceEngine.findPrevious()
                }
            },

            // Phase 6: Zen mode
            CommandDefinition(
                id: "view.zenMode",
                name: "Toggle Zen Mode",
                category: .view,
                defaultShortcut: "cmd+shift+return"
            ) { [weak self] in
                self?.isZenModeEnabled.toggle()
                self?.zenModeController.toggle(window: NSApp.keyWindow)
            },

            // Phase 6: Statistics
            CommandDefinition(
                id: "view.toggleStatistics",
                name: "Toggle Statistics Bar",
                category: .view
            ) { [weak self] in
                self?.isStatisticsBarVisible.toggle()
            },

            // Phase 8: AI commands
            CommandDefinition(
                id: "ai.togglePanel",
                name: "Toggle AI Assistant",
                category: .tools,
                defaultShortcut: "cmd+shift+a"
            ) { [weak self] in
                self?.aiAssistantState.isVisible.toggle()
            },

            CommandDefinition(
                id: "ai.complete",
                name: "AI: Complete",
                category: .tools
            ) { [weak self] in
                self?.runAITask(.complete)
            },

            CommandDefinition(
                id: "ai.summarize",
                name: "AI: Summarize",
                category: .tools
            ) { [weak self] in
                self?.runAITask(.summarize)
            },

            CommandDefinition(
                id: "ai.rewrite",
                name: "AI: Rewrite",
                category: .tools
            ) { [weak self] in
                self?.runAITask(.rewrite)
            },

            CommandDefinition(
                id: "ai.fixGrammar",
                name: "AI: Fix Grammar",
                category: .tools
            ) { [weak self] in
                self?.runAITask(.fixGrammar)
            },

            CommandDefinition(
                id: "ai.translate",
                name: "AI: Translate",
                category: .tools
            ) { [weak self] in
                self?.runAITask(.translate)
            },

            // Tools
            CommandDefinition(
                id: "tools.toggleVimMode",
                name: "Toggle Vim Mode",
                category: .tools
            ) { [weak self] in
                self?.vimModeHandler.isEnabled.toggle()
            },

            CommandDefinition(
                id: "tools.appleWritingTools",
                name: "Apple Writing Tools",
                category: .tools
            ) { [weak self] in
                self?.sendAppAction("showWritingTools:")
            },
        ])
    }

    private func sendAppAction(_ selector: String) {
        NSApp.sendAction(Selector(selector), to: nil, from: nil)
    }

    func openDocument() {
        NSDocumentController.shared.openDocument(nil)
    }

    func runAITask(_ taskType: AITaskType) {
        aiAssistantState.selectedTask = taskType
        aiAssistantState.isVisible = true

        if let manipulator = activeTextManipulator {
            let selected = manipulator.selectedText
            let context = manipulator.fullText
            aiAssistantState.run(
                text: selected.isEmpty ? context : selected,
                context: selected.isEmpty ? "" : context,
                configuration: aiConfiguration
            )
        }
    }
}
