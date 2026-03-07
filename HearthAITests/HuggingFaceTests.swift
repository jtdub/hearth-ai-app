import Foundation
import Testing
@testable import HearthAI

// MARK: - Download URL Construction

@Test func downloadURLNormalRepo() {
    let api = HuggingFaceAPI()
    let url = api.downloadURL(
        repoId: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
        fileName: "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
    )
    let expected = "https://huggingface.co/"
        + "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF"
        + "/resolve/main/"
        + "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
    #expect(url.absoluteString == expected)
}

@Test func downloadURLPreservesPath() {
    let api = HuggingFaceAPI()
    let url = api.downloadURL(
        repoId: "user/repo",
        fileName: "model.gguf"
    )
    #expect(url.absoluteString.contains("/resolve/main/"))
    #expect(url.absoluteString.hasPrefix("https://huggingface.co/"))
    #expect(url.absoluteString.hasSuffix("model.gguf"))
}

@Test func downloadURLEncodesSpaces() {
    let api = HuggingFaceAPI()
    let url = api.downloadURL(
        repoId: "user/my repo",
        fileName: "my model.gguf"
    )
    #expect(!url.absoluteString.contains(" "))
    #expect(url.absoluteString.contains("%20"))
}

// MARK: - HFModelInfo

@Test func displayNameExtractsLastComponent() {
    let model = HFModelInfo(
        id: "TheBloke/TinyLlama-GGUF",
        author: "TheBloke",
        downloads: 100,
        likes: 10,
        tags: [],
        isPrivate: false,
        isGated: false,
        lastModified: nil
    )
    #expect(model.displayName == "TinyLlama-GGUF")
}

@Test func displayNameWithNoSlashReturnsId() {
    let model = HFModelInfo(
        id: "simple-model",
        author: nil,
        downloads: 0,
        likes: 0,
        tags: [],
        isPrivate: false,
        isGated: nil,
        lastModified: nil
    )
    #expect(model.displayName == "simple-model")
}

@Test func modelFamilyDetection() {
    let families: [(String, String)] = [
        ("user/llama-2-7b-GGUF", "Llama"),
        ("user/mistral-7b-GGUF", "Mistral"),
        ("user/phi-3-mini-GGUF", "Phi"),
        ("user/qwen2-1.5b-GGUF", "Qwen"),
        ("user/gemma-2b-GGUF", "Gemma"),
        ("user/SmolLM-360M-GGUF", "Smollm"),
        ("user/TinyLlama-1.1B-GGUF", "Llama"),
        ("user/some-random-model", "Unknown"),
    ]

    for (id, expected) in families {
        let model = HFModelInfo(
            id: id, author: nil, downloads: 0, likes: 0,
            tags: [], isPrivate: false, isGated: nil,
            lastModified: nil
        )
        #expect(
            model.modelFamily == expected,
            "Expected \(expected) for \(id), got \(model.modelFamily)"
        )
    }
}

// MARK: - HFFileInfo

@Test func fileInfoGGUFSubdirectoryPath() {
    let file = HFFileInfo(
        type: "file",
        path: "subfolder/model-q4_k_m.gguf",
        size: 1_000_000
    )
    #expect(file.fileName == "model-q4_k_m.gguf")
    #expect(file.isGGUF == true)
    #expect(file.id == "subfolder/model-q4_k_m.gguf")
}

@Test func fileInfoNonGGUFExtensions() {
    let extensions = [
        "model.bin", "README.md", "config.json",
        "model.safetensors", "model.gguf.part1",
    ]
    for ext in extensions {
        let file = HFFileInfo(type: "file", path: ext, size: 100)
        #expect(
            file.isGGUF == false,
            "\(ext) should not be detected as GGUF"
        )
    }
}

@Test func fileInfoQuantizationVariants() {
    let cases: [(String, String)] = [
        ("model-q2_k.gguf", "Q2_K"),
        ("model-q3_k_s.gguf", "Q3_K_S"),
        ("model-q3_k_m.gguf", "Q3_K_M"),
        ("model-q3_k_l.gguf", "Q3_K_L"),
        ("model-q4_0.gguf", "Q4_0"),
        ("model-q4_1.gguf", "Q4_1"),
        ("model-q4_k_s.gguf", "Q4_K_S"),
        ("model-q4_k_m.gguf", "Q4_K_M"),
        ("model-q5_0.gguf", "Q5_0"),
        ("model-q5_1.gguf", "Q5_1"),
        ("model-q5_k_s.gguf", "Q5_K_S"),
        ("model-q5_k_m.gguf", "Q5_K_M"),
        ("model-q6_k.gguf", "Q6_K"),
        ("model-q8_0.gguf", "Q8_0"),
        ("model-f16.gguf", "F16"),
        ("model-f32.gguf", "F32"),
        ("model-iq2_xxs.gguf", "IQ2_XXS"),
        ("model-iq2_xs.gguf", "IQ2_XS"),
        ("model-iq3_xxs.gguf", "IQ3_XXS"),
        ("model-iq3_xs.gguf", "IQ3_XS"),
    ]

    for (fileName, expected) in cases {
        let file = HFFileInfo(
            type: "file", path: fileName, size: 1000
        )
        #expect(
            file.quantization == expected,
            "Expected \(expected) for \(fileName)"
        )
    }
}

@Test func fileInfoUnknownQuantization() {
    let file = HFFileInfo(
        type: "file", path: "model.gguf", size: 1000
    )
    #expect(file.quantization == "Unknown")
}

@Test func fileInfoFormattedSizeWithNilSize() {
    let file = HFFileInfo(type: "file", path: "model.gguf", size: nil)
    #expect(file.formattedSize == "Unknown")
}

@Test func fileInfoFormattedSizeWithValue() {
    let file = HFFileInfo(
        type: "file", path: "model.gguf", size: 1_000_000_000
    )
    let formatted = file.formattedSize
    #expect(!formatted.isEmpty)
    #expect(formatted != "Unknown")
}

// MARK: - FeaturedModel

@Test func featuredModelId() {
    let model = FeaturedModel(
        repoId: "user/repo",
        fileName: "model.gguf",
        displayName: "Test",
        modelFamily: "Llama",
        quantization: "Q4_K_M",
        sizeBytes: 1_000_000,
        description: "A test model"
    )
    #expect(model.id == "user/repo/model.gguf")
}

@Test func featuredModelFormattedSize() {
    let model = FeaturedModel(
        repoId: "user/repo",
        fileName: "model.gguf",
        displayName: "Test",
        modelFamily: "Llama",
        quantization: "Q4_K_M",
        sizeBytes: 1_073_741_824,
        description: "A test model"
    )
    #expect(!model.formattedSize.isEmpty)
}
