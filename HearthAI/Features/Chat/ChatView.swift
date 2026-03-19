import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(InferenceService.self) private var inferenceService
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var showModelPicker = false
    @State private var showConversations = false
    @State private var showChatSettings = false
    @State private var showDocumentPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                if appState.thermalMonitor.shouldWarnUser {
                    thermalWarning
                }
                if viewModel.attachedDocument != nil {
                    documentBadge
                }
                inputBar
            }
            .navigationTitle("Hearth AI")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { chatToolbar }
            .sheet(isPresented: $showModelPicker) {
                ModelPickerSheet()
            }
            .sheet(isPresented: $showConversations) {
                conversationSheet
            }
            .sheet(isPresented: $showChatSettings) {
                chatSettingsSheet
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerSheet(onSelect: { document in
                    viewModel.attachDocument(document)
                })
            }
            .alert(
                "Inference Error",
                isPresented: .init(
                    get: { viewModel.inferenceError != nil },
                    set: {
                        if !$0 { viewModel.inferenceError = nil }
                    }
                )
            ) {
                Button("OK") { viewModel.inferenceError = nil }
            } message: {
                Text(viewModel.inferenceError ?? "")
            }
        }
        .onAppear {
            viewModel.inferenceService = inferenceService
            viewModel.thermalMonitor = appState.thermalMonitor
            viewModel.modelContext = modelContext
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var chatToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 12) {
                Button {
                    showConversations = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                Button {
                    showModelPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                        if inferenceService.isModelLoaded {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    viewModel.newConversation()
                } label: {
                    Label("New Chat", systemImage: "plus")
                }
                Button {
                    Task { await viewModel.regenerateLastResponse() }
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
                .disabled(!canRegenerate)
                Button {
                    showChatSettings = true
                } label: {
                    Label("Chat Settings", systemImage: "slider.horizontal.3")
                }
                Divider()
                Button(role: .destructive) {
                    viewModel.clearMessages()
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                }
                .disabled(viewModel.messages.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Sheets

    private var conversationSheet: some View {
        ConversationListView(
            onSelect: { viewModel.loadConversation($0) },
            onNew: { viewModel.newConversation() },
            onDelete: { viewModel.deleteConversation($0) }
        )
    }

    private var chatSettingsSheet: some View {
        ChatSettingsSheet(
            systemPrompt: viewModel.activeConversation?.systemPrompt
                ?? "You are a helpful assistant.",
            temperature: viewModel.activeConversation?.temperature
                ?? Constants.defaultTemperature,
            topP: viewModel.activeConversation?.topP
                ?? Constants.defaultTopP,
            useMemory: viewModel.activeConversation?.useMemory ?? true,
            onSave: { prompt, temp, top, memory in
                viewModel.updateConversationSettings(
                    systemPrompt: prompt,
                    temperature: temp,
                    topP: top,
                    useMemory: memory
                )
            }
        )
    }

    private var canRegenerate: Bool {
        viewModel.messages.last?.role == .assistant && !viewModel.isGenerating
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
            .scrollDismissesKeyboard(.interactively)
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
            if inferenceService.isLoading {
                    ProgressView()
                        .padding(.top, 4)
                    Text("Loading model...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !inferenceService.isModelLoaded {
                    Text(
                        "No model loaded."
                            + " Tap the brain icon to select one."
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
                }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var documentBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.caption)
            Text(viewModel.attachedDocument?.title ?? "")
                .font(.caption)
                .lineLimit(1)
            Button {
                viewModel.detachDocument()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.blue.opacity(0.1))
        .clipShape(Capsule())
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                showDocumentPicker = true
            } label: {
                Image(systemName: "doc.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

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
                        .foregroundStyle(
                            inputText.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty ? .gray : .accentColor
                        )
                }
                .disabled(
                    inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !inferenceService.isModelLoaded
                )
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
        .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
}
