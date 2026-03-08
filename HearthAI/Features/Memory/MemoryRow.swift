import SwiftUI

struct MemoryRow: View {
    let memory: Memory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(
                    memory.memoryCategory.displayName,
                    systemImage: memory.memoryCategory.systemImage
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                if !memory.isActive {
                    Text("Inactive")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Text(memory.content)
                .font(.body)
                .lineLimit(3)

            Text(memory.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
