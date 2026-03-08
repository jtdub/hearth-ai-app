import SwiftUI

struct ChatSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var systemPrompt: String
    @State var temperature: Float
    @State var topP: Float
    @State var useMemory: Bool
    let onSave: (String, Float, Float, Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 80)
                }

                Section("Temperature") {
                    HStack {
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                        Text(String(format: "%.1f", temperature))
                            .monospacedDigit()
                            .frame(width: 36)
                    }
                    Text("Lower = more focused. Higher = more creative.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Top P") {
                    HStack {
                        Slider(value: $topP, in: 0...1, step: 0.05)
                        Text(String(format: "%.2f", topP))
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                    Text("Controls diversity of token sampling.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Memory") {
                    Toggle("Use Memory", isOn: $useMemory)
                    Text(
                        "Include personal memories in context."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Chat Settings")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            systemPrompt, temperature,
                            topP, useMemory
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
