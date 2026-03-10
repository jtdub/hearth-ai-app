import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    section(
                        title: "Overview",
                        body: """
                            Hearth AI is designed with privacy as a core principle. \
                            All AI processing happens entirely on your device. \
                            No data ever leaves your device.
                            """
                    )

                    section(
                        title: "Data Collection",
                        body: """
                            Hearth AI collects no data. We do not collect, store, \
                            transmit, or share any personal information, usage data, \
                            analytics, or telemetry of any kind.
                            """
                    )

                    section(
                        title: "On-Device Processing",
                        body: """
                            All AI model inference runs locally on your device \
                            using on-device hardware acceleration. Your conversations, \
                            documents, and memories are stored only on your device \
                            using Apple's SwiftData framework. Model files are \
                            downloaded directly from Hugging Face Hub to your device.
                            """
                    )
                }

                Group {
                    section(
                        title: "Network Usage",
                        body: """
                            The only network requests Hearth AI makes are to browse \
                            and search models on Hugging Face Hub, and to download \
                            model weight files. No user data, conversations, or \
                            personal information is included in any network request.
                            """
                    )

                    section(
                        title: "Third-Party Services",
                        body: """
                            Hearth AI connects to Hugging Face Hub solely for model \
                            discovery and download. Please refer to Hugging Face's \
                            privacy policy for details on their data practices.
                            """
                    )

                    section(
                        title: "Data Storage",
                        body: """
                            All app data — conversations, documents, memories, and \
                            downloaded models — is stored locally on your device and \
                            never leaves it.
                            """
                    )

                    section(
                        title: "Children's Privacy",
                        body: """
                            Hearth AI does not collect any data from any users, \
                            including children.
                            """
                    )
                }

                Text("Last updated: March 9, 2026")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
