import SwiftUI

struct MemoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var content: String
    @State var category: MemoryCategory
    @State var isActive: Bool
    let isNew: Bool
    let onSave: (String, MemoryCategory, Bool) -> Void

    init(
        memory: Memory? = nil,
        onSave: @escaping (String, MemoryCategory, Bool) -> Void
    ) {
        _content = State(initialValue: memory?.content ?? "")
        _category = State(
            initialValue: memory?.memoryCategory ?? .other
        )
        _isActive = State(initialValue: memory?.isActive ?? true)
        isNew = memory == nil
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 80)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(
                            MemoryCategory.allCases, id: \.self
                        ) { cat in
                            Label(
                                cat.displayName,
                                systemImage: cat.systemImage
                            )
                            .tag(cat)
                        }
                    }
                }

                if !isNew {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(isNew ? "New Memory" : "Edit Memory")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(content, category, isActive)
                        dismiss()
                    }
                    .disabled(
                        content
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                }
            }
        }
    }
}
