import SwiftUI
import UniformTypeIdentifiers

struct ShareView: View {
    weak var extensionContext: NSExtensionContext?
    @State private var sharedText = ""
    @State private var selectedTask: SharedInferenceRequest.TaskType = .ask
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var availableModels: [SharedModelInfo] {
        SharedModelInfo.loadFromSharedContainer()
    }

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    ProgressView("Loading shared content...")
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                } else {
                    Section("Shared Text") {
                        Text(sharedText)
                            .lineLimit(10)
                            .font(.body)
                    }

                    Section("Action") {
                        Picker("Task", selection: $selectedTask) {
                            ForEach(
                                SharedInferenceRequest.TaskType.allCases,
                                id: \.self
                            ) { task in
                                Text(task.displayName).tag(task)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if availableModels.isEmpty {
                        Section {
                            Text(
                                "No models downloaded. "
                                + "Open Hearth AI to download a model."
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Hearth AI")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        extensionContext?.completeRequest(
                            returningItems: nil
                        )
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Process") {
                        processSharedContent()
                    }
                    .disabled(
                        sharedText.isEmpty || availableModels.isEmpty
                    )
                }
            }
        }
        .task {
            await extractSharedContent()
        }
    }

    private func extractSharedContent() async {
        guard let items = extensionContext?.inputItems
            as? [NSExtensionItem] else {
            errorMessage = "No content to process."
            isLoading = false
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(
                    UTType.plainText.identifier
                ) {
                    if let text = try? await provider.loadItem(
                        forTypeIdentifier: UTType.plainText.identifier
                    ) as? String {
                        sharedText = text
                        isLoading = false
                        return
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(
                    UTType.url.identifier
                ) {
                    if let url = try? await provider.loadItem(
                        forTypeIdentifier: UTType.url.identifier
                    ) as? URL {
                        sharedText = url.absoluteString
                        isLoading = false
                        return
                    }
                }
            }
        }

        errorMessage = "Could not extract text from shared content."
        isLoading = false
    }

    private func processSharedContent() {
        let request = SharedInferenceRequest(
            inputText: sharedText,
            taskType: selectedTask,
            modelId: availableModels.first?.id
        )

        do {
            try request.save()
        } catch {
            errorMessage = "Failed to save request: \(error.localizedDescription)"
            return
        }

        let urlString = "\(AppGroupConstants.urlScheme)://"
            + "process-shared?requestId=\(request.id.uuidString)"
        guard let url = URL(string: urlString) else { return }

        extensionContext?.open(url) { _ in
            self.extensionContext?.completeRequest(
                returningItems: nil
            )
        }
    }
}
