import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Privacy Policy")
                        .font(.title.bold())

                    Text("Last updated: March 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                section(
                    title: "Data Collection",
                    body: """
                    Hearth AI does not collect, store, or transmit any personal data. \
                    All conversations and AI inference happen entirely on your device. \
                    No analytics, telemetry, or usage data is gathered.
                    """
                )

                section(
                    title: "On-Device Processing",
                    body: """
                    All AI model inference runs locally on your iPhone using the \
                    open-source llama.cpp library. Your conversations never leave \
                    your device. There are no servers, no cloud processing, and no \
                    third-party AI services involved.
                    """
                )

                section(
                    title: "Model Downloads",
                    body: """
                    Model files are downloaded directly from Hugging Face Hub \
                    (huggingface.co) to your device. These downloads are standard \
                    HTTPS requests for publicly available neural network weight files. \
                    No account or authentication is required. Hearth AI does not send \
                    any user data to Hugging Face.
                    """
                )

                section(
                    title: "Local Storage",
                    body: """
                    Conversations and downloaded models are stored locally on your \
                    device using standard iOS storage. This data is protected by your \
                    device's encryption and security features. You can delete all data \
                    at any time from within the app or by uninstalling it.
                    """
                )

                section(
                    title: "No Tracking",
                    body: """
                    Hearth AI does not use any advertising identifiers, analytics \
                    frameworks, or tracking technologies. There is no App Tracking \
                    Transparency prompt because there is nothing to track.
                    """
                )

                section(
                    title: "Contact",
                    body: """
                    If you have questions about this privacy policy, please visit \
                    the Hearth AI repository on GitHub.
                    """
                )
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
