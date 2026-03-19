import SwiftUI
import SwiftData

struct MemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memory.updatedAt, order: .reverse)
    private var memories: [Memory]
    @State private var showAddSheet = false
    @State private var editingMemory: Memory?
    @State private var searchText = ""
    @State private var showExportSheet = false

    private var filteredMemories: [Memory] {
        guard !searchText.isEmpty else { return memories }
        let query = searchText.lowercased()
        return memories.filter {
            $0.content.lowercased().contains(query)
                || $0.memoryCategory.displayName.lowercased()
                    .contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    emptyState
                } else {
                    memoryList
                }
            }
            .navigationTitle("Memory")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search memories")
            .toolbar { memoryToolbar }
            .sheet(isPresented: $showAddSheet) {
                MemoryEditSheet { content, category, isActive in
                    addMemory(
                        content: content,
                        category: category,
                        isActive: isActive
                    )
                }
            }
            .sheet(item: $editingMemory) { memory in
                MemoryEditSheet(memory: memory) { content, cat, active in
                    updateMemory(
                        memory, content: content,
                        category: cat, isActive: active
                    )
                }
            }
            .sheet(isPresented: $showExportSheet) {
                exportSheet
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var memoryToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Memory", systemImage: "plus")
                }
                Button {
                    showExportSheet = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(memories.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        ContentUnavailableView(
            "No Memories",
            systemImage: "brain.head.profile",
            description: Text(
                "Add memories to personalize your conversations."
            )
        )
    }

    private var memoryList: some View {
        List {
            ForEach(filteredMemories) { memory in
                MemoryRow(memory: memory)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingMemory = memory
                    }
                    .contextMenu {
                        Button {
                            editingMemory = memory
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            modelContext.delete(memory)
                            try? modelContext.save()
                        } label: {
                            Label(
                                "Delete",
                                systemImage: "trash"
                            )
                        }
                    }
            }
            .onDelete(perform: deleteMemories)
        }
    }

    private var exportSheet: some View {
        NavigationStack {
            let json = exportJSON()
            ScrollView {
                Text(json)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Export Memories")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showExportSheet = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: json,
                        subject: Text("Hearth AI Memories")
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func addMemory(
        content: String,
        category: MemoryCategory,
        isActive: Bool
    ) {
        let memory = Memory(
            content: content.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            category: category,
            isActive: isActive
        )
        modelContext.insert(memory)
        try? modelContext.save()
    }

    private func updateMemory(
        _ memory: Memory,
        content: String,
        category: MemoryCategory,
        isActive: Bool
    ) {
        memory.content = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        memory.category = category.rawValue
        memory.isActive = isActive
        memory.updatedAt = .now
        memory.tokenEstimate = Int32(memory.content.count / 4)
        try? modelContext.save()
    }

    private func deleteMemories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredMemories[index])
        }
        try? modelContext.save()
    }

    private func exportJSON() -> String {
        let items = memories.map { memory in
            [
                "content": memory.content,
                "category": memory.memoryCategory.displayName,
                "active": memory.isActive ? "true" : "false",
                "created": ISO8601DateFormatter().string(
                    from: memory.createdAt
                ),
                "updated": ISO8601DateFormatter().string(
                    from: memory.updatedAt
                )
            ]
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: items, options: .prettyPrinted
        ),
            let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}
