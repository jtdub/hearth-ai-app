import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme = "system"
    @AppStorage("defaultModelId") private var defaultModelId = ""
    @Environment(InferenceService.self) private var inferenceService
    @Query(sort: \LocalModel.downloadedAt, order: .reverse)
    private var models: [LocalModel]

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
                                Text(model.displayName)
                                    .tag(model.id)
                            }
                        }
                        .onChange(of: defaultModelId) {
                            loadSelectedModel()
                        }
                    }
                }
                .onAppear {
                    syncDefaultModel()
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
                    // swiftlint:disable:next force_unwrapping
                    let issuesURL = URL(string: "https://github.com/jtdub/hearth-ai-app/issues")!
                    Link(destination: issuesURL) {
                        Label("Report a Bug or Give Feedback", systemImage: "ladybug")
                    }
                }

                Section("Legal") {
                    // swiftlint:disable:next force_unwrapping
                    let supportURL = URL(string: "https://www.jtdub.com/apps/support/hearth-ai/")!
                    Link(destination: supportURL) {
                        Label("Privacy Policy & Support", systemImage: "safari")
                    }
                    NavigationLink("Open Source Licenses") {
                        LicensesView()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func syncDefaultModel() {
        if defaultModelId.isEmpty,
           let loadedId = inferenceService.loadedModelId {
            defaultModelId = loadedId
        }
    }

    private func loadSelectedModel() {
        guard !defaultModelId.isEmpty,
              inferenceService.loadedModelId != defaultModelId,
              let model = models.first(where: {
                  $0.id == defaultModelId
              }) else { return }
        Task {
            try? await inferenceService.loadModel(model)
        }
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section("Hearth AI") {
                Text("MIT License")
                    .font(.headline)
                Text("""
                    Copyright (c) 2026 James Williams

                    Permission is hereby granted, free of charge, to any person obtaining \
                    a copy of this software and associated documentation files, to deal in \
                    the Software without restriction, including without limitation the rights \
                    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
                    copies of the Software, and to permit persons to whom the Software is \
                    furnished to do so, subject to the following conditions:

                    The above copyright notice and this permission notice shall be included \
                    in all copies or substantial portions of the Software.

                    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS \
                    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
                    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
                    """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

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
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: LocalModel.self, inMemory: true)
}
