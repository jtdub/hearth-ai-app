import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme = "system"
    @AppStorage("defaultModelId") private var defaultModelId = ""
    @Query(sort: \LocalModel.downloadedAt, order: .reverse) private var models: [LocalModel]

    var body: some View {
        NavigationStack {
            Form {
                Section("Default Model") {
                    if models.isEmpty {
                        Text("No models downloaded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Model", selection: $defaultModelId) {
                            Text("None").tag("")
                            ForEach(models) { model in
                                Text(model.displayName).tag(model.id)
                            }
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }

                Section("Storage") {
                    let space = FileManager.availableDiskSpace
                    let used = models.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
                    LabeledContent("Models Storage") {
                        Text(ByteCountFormatter.string(
                            fromByteCount: used, countStyle: .file
                        ))
                    }
                    LabeledContent("Available Space") {
                        Text(ByteCountFormatter.string(
                            fromByteCount: space, countStyle: .file
                        ))
                    }
                    LabeledContent("Device Memory") {
                        Text(DeviceCapability.availableMemoryFormatted)
                    }
                }

                Section("About") {
                    let version = Bundle.main.infoDictionary?[
                        "CFBundleShortVersionString"
                    ] as? String ?? "1.0"
                    LabeledContent("Version", value: version)
                    LabeledContent("Powered by", value: "llama.cpp")
                }

                Section("Legal") {
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                    NavigationLink("Open Source Licenses") {
                        LicensesView()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section("llama.cpp") {
                Text("MIT License")
                    .font(.headline)
                Text("""
                    Copyright (c) 2023-2024 The ggml authors

                    Permission is hereby granted, free of charge, to any person obtaining \
                    a copy of this software and associated documentation files, to deal in \
                    the Software without restriction, including without limitation the rights \
                    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
                    copies of the Software.
                    """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Hugging Face") {
                Text("Model data provided by Hugging Face Hub API.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: LocalModel.self, inMemory: true)
}
