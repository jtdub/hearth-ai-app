import SwiftUI

struct ChatView: View {
    @Environment(InferenceService.self) private var inferenceService
    @Environment(AppState.self) private var appState
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                if appState.thermalMonitor.shouldWarnUser {
                    thermalWarning
                }
                inputBar
            }
            .navigationTitle("Hearth AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.clearMessages()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
        }
        .onAppear {
            viewModel.inferenceService = inferenceService
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty && !viewModel.isGenerating {
                        emptyState
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                    }

                    if viewModel.isGenerating {
                        MessageBubble(
                            role: .assistant,
                            content: viewModel.streamingText.isEmpty
                                ? "..."
                                : viewModel.streamingText
                        )
                        .id("streaming")
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.streamingText) {
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "flame")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Welcome to Hearth AI")
                .font(.title2.bold())
            Text("Your private, on-device AI assistant.\nType a message to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !inferenceService.isModelLoaded {
                Text("No model loaded. Visit the Models tab to download one.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 20))

            if viewModel.isGenerating {
                Button {
                    Task { await viewModel.stopGenerating() }
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            } else {
                Button {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    inputText = ""
                    Task { await viewModel.send(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? .gray : .accentColor)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || !inferenceService.isModelLoaded)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Thermal Warning

    private var thermalWarning: some View {
        HStack {
            Image(systemName: "thermometer.sun.fill")
                .foregroundStyle(.orange)
            Text(appState.thermalMonitor.warningMessage ?? "")
                .font(.caption)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.orange.opacity(0.15))
    }
}

#Preview {
    ChatView()
        .environment(AppState())
        .environment(InferenceService())
}
