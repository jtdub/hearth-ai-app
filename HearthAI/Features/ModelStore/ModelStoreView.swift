import SwiftUI

struct ModelStoreView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Model Store")
                    .font(.title2.bold())
                Text("Browse and download AI models.\nComing in Phase 2.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .navigationTitle("Models")
        }
    }
}

#Preview {
    ModelStoreView()
}
