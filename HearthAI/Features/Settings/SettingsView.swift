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
                    let space = FileManager.availableDiskSpace
                    LabeledContent("Available Space") {
                        Text(ByteCountFormatter.string(
                            fromByteCount: space, countStyle: .file
                        ))
                    }
                }

                Section("About") {
                    let version = Bundle.main.infoDictionary?[
                        "CFBundleShortVersionString"
                    ] as? String ?? "1.0"
                    LabeledContent("Version", value: version)
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
