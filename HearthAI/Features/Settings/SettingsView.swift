import SwiftUI

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme = "system"

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }

                Section("Storage") {
                    LabeledContent("Available Space") {
                        Text(ByteCountFormatter.string(
                            fromByteCount: FileManager.availableDiskSpace,
                            countStyle: .file
                        ))
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Powered by", value: "llama.cpp")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
