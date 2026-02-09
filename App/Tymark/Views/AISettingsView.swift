import SwiftUI
import TymarkAI

// MARK: - AI Settings View

struct AISettingsView: View {
    @ObservedObject var configuration: AIConfiguration
    @ObservedObject var privacyManager: AIPrivacyManager
    @State private var apiKeyInput: String = ""
    @State private var showAPIKey: Bool = false

    var body: some View {
        Form {
            Section("Engine") {
                Picker("AI Engine", selection: $configuration.selectedEngine) {
                    ForEach(AIEngineType.allCases, id: \.rawValue) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }

                if configuration.selectedEngine != .local {
                    Picker("Cloud Model", selection: $configuration.cloudModel) {
                        ForEach(AIConfiguration.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
            }

            Section("API Key") {
                HStack {
                    if showAPIKey {
                        TextField("API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                HStack {
                    Button("Save Key") {
                        configuration.apiKey = apiKeyInput
                        apiKeyInput = ""
                    }
                    .disabled(apiKeyInput.isEmpty)

                    if configuration.hasAPIKey {
                        Button("Remove Key") {
                            configuration.apiKey = nil
                            apiKeyInput = ""
                        }
                        .foregroundColor(.red)
                    }

                    Spacer()

                    if configuration.hasAPIKey {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Key stored")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("Privacy") {
                Toggle("Local-only mode", isOn: $privacyManager.isLocalOnly)

                if !privacyManager.isLocalOnly {
                    Toggle("Cloud AI consent", isOn: $privacyManager.cloudConsentGiven)

                    Text("When cloud AI is enabled, your text is sent to Anthropic's API for processing. Your data is not stored or used for training.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: privacyManager.isLocalOnly ? "lock.fill" : "globe")
                        .foregroundColor(privacyManager.isLocalOnly ? .green : .blue)
                    Text(privacyManager.isLocalOnly ? "All processing stays on your device" : "Cloud processing enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}
