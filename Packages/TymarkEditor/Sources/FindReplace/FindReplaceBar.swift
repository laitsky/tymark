import SwiftUI

// MARK: - Find & Replace Bar

public struct FindReplaceBar: View {
    @ObservedObject var engine: FindReplaceEngine
    @Binding var isVisible: Bool
    @State private var showReplace = false
    @FocusState private var isSearchFocused: Bool

    public init(engine: FindReplaceEngine, isVisible: Binding<Bool>) {
        self.engine = engine
        self._isVisible = isVisible
    }

    public var body: some View {
        VStack(spacing: 4) {
            // Search row
            HStack(spacing: 6) {
                // Search field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Find...", text: $engine.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isSearchFocused)
                        .onSubmit { engine.findNext() }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(4)
                .frame(minWidth: 200)

                // Match count
                Text(engine.matchCountDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 60)

                // Navigation buttons
                Button(action: { engine.findPrevious() }) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(engine.matches.isEmpty)

                Button(action: { engine.findNext() }) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(engine.matches.isEmpty)

                Divider().frame(height: 16)

                // Toggle buttons
                Toggle(isOn: $engine.isRegexEnabled) {
                    Text(".*")
                        .font(.system(size: 11, design: .monospaced))
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Regular Expression")

                Toggle(isOn: $engine.isCaseSensitive) {
                    Text("Aa")
                        .font(.system(size: 11))
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Match Case")

                Toggle(isOn: $engine.isWholeWord) {
                    Text("W")
                        .font(.system(size: 11, weight: .bold))
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Whole Word")

                Divider().frame(height: 16)

                // Replace toggle
                Button(action: { showReplace.toggle() }) {
                    Image(systemName: showReplace ? "chevron.up.chevron.down" : "arrow.left.arrow.right")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Toggle Replace")

                // Close button
                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
            }

            // Replace row (expandable)
            if showReplace {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        TextField("Replace...", text: $engine.replaceText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
                    .frame(minWidth: 200)

                    Button("Replace") {
                        engine.replaceCurrent()
                    }
                    .controlSize(.small)
                    .disabled(engine.matches.isEmpty)

                    Button("Replace All") {
                        engine.replaceAll()
                    }
                    .controlSize(.small)
                    .disabled(engine.matches.isEmpty)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor)),
            alignment: .bottom
        )
        .onAppear {
            isSearchFocused = true
        }
    }
}
