import SwiftUI
import SwiftData

/// View shown when the app receives a shared request from the
/// Share Extension.
struct SharedRequestView: View {
    @Environment(SharedRequestHandler.self) private var handler
    @Environment(InferenceService.self) private var inferenceService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if handler.isProcessing {
                    processingView
                } else if let result = handler.resultText {
                    resultView(result)
                } else if let error = handler.errorMessage {
                    errorView(error)
                } else if let request = handler.pendingRequest {
                    pendingView(request)
                }
            }
            .navigationTitle("Shared Request")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        handler.dismiss()
                        dismiss()
                    }
                }
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Processing with local AI...")
                .font(.headline)
            Text("Running on-device, fully private.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func resultView(_ result: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Result")
                    .font(.headline)
                Text(result)
                    .textSelection(.enabled)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Copy to Clipboard") {
                    copyToClipboard(result)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Processing Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        }
    }

    private func pendingView(
        _ request: SharedInferenceRequest
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task: \(request.taskType.displayName)")
                .font(.headline)
            Text(request.inputText)
                .lineLimit(10)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("Process Now") {
                Task {
                    await handler.processRequest(
                        inferenceService: inferenceService,
                        context: modelContext
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
