import Foundation
import SwiftData

/// Utility to register existing downloaded model files that aren't in the database.
struct ModelMigration {
    
    /// Scans the models directory and creates database entries for any .gguf files
    /// that don't already have a LocalModel entry.
    @MainActor
    static func registerExistingModels(context: ModelContext) {
        let modelsDir = FileManager.modelsDirectory
        
        print("🔍 Scanning for unregistered models in: \(modelsDir.path)")
        
        // Get all files in the models directory (including subdirectories)
        guard let enumerator = FileManager.default.enumerator(
            at: modelsDir,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("❌ Could not enumerate models directory")
            return
        }
        
        var registeredCount = 0
        var skippedCount = 0
        
        for case let fileURL as URL in enumerator {
            // Skip directories
            guard let isDirectory = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  !isDirectory else {
                continue
            }
            
            // Only process .gguf files
            guard fileURL.pathExtension.lowercased() == "gguf" else {
                continue
            }
            
            let fileName = fileURL.lastPathComponent
            
            // Calculate relative path from models directory
            let relativePath = fileURL.path.replacingOccurrences(
                of: modelsDir.path + "/",
                with: ""
            )
            
            // Check if already registered by checking fileName
            let descriptor = FetchDescriptor<LocalModel>(
                predicate: #Predicate { model in
                    model.fileName == fileName || model.localPath == relativePath
                }
            )
            
            if (try? context.fetchCount(descriptor)) ?? 0 > 0 {
                print("⏭️  Skipping \(fileName) - already registered")
                skippedCount += 1
                continue
            }
            
            // Get file size
            let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attrs?[.size] as? Int64) ?? 0
            
            // Extract model info from filename
            let displayName = fileName
                .replacingOccurrences(of: ".gguf", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
            
            // Create new LocalModel entry
            let model = LocalModel(
                id: UUID().uuidString,
                repoId: extractRepoId(from: relativePath, fileName: fileName),
                fileName: fileName,
                displayName: displayName,
                modelFamily: extractModelFamily(from: fileName),
                quantization: extractQuantization(from: fileName),
                fileSizeBytes: fileSize,
                downloadedAt: extractDownloadDate(from: fileURL),
                localPath: relativePath
            )
            
            context.insert(model)
            print("✅ Registered: \(fileName) (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))")
            registeredCount += 1
        }
        
        // Save all changes
        if registeredCount > 0 {
            do {
                try context.save()
                print("💾 Saved \(registeredCount) new model(s) to database")
            } catch {
                print("❌ Failed to save models: \(error)")
            }
        }
        
        print("📊 Migration complete: \(registeredCount) registered, \(skippedCount) skipped")
    }
    
    // MARK: - Helper Functions
    
    private static func extractRepoId(from relativePath: String, fileName: String) -> String {
        // If the file is in a subdirectory, use that as part of repo ID
        let components = relativePath.split(separator: "/")
        if components.count > 1 {
            return components.dropLast().joined(separator: "/").replacingOccurrences(of: "_", with: "/")
        }
        return "local/unknown"
    }
    
    private static func extractModelFamily(from fileName: String) -> String {
        let name = fileName.lowercased()
        let families = [
            "llama-3": "Llama 3",
            "llama-2": "Llama 2", 
            "llama": "Llama",
            "mistral": "Mistral",
            "phi": "Phi",
            "qwen": "Qwen",
            "gemma": "Gemma",
            "smollm": "SmolLM",
            "tinyllama": "TinyLlama",
            "openhermes": "OpenHermes",
            "hermes": "Hermes",
            "codellama": "CodeLlama",
            "vicuna": "Vicuna",
            "orca": "Orca"
        ]
        
        for (key, value) in families {
            if name.contains(key) {
                return value
            }
        }
        
        return "Unknown"
    }
    
    private static func extractQuantization(from fileName: String) -> String {
        let name = fileName.uppercased()
        let quants = [
            "Q2_K", "Q3_K_S", "Q3_K_M", "Q3_K_L",
            "Q4_0", "Q4_1", "Q4_K_S", "Q4_K_M",
            "Q5_0", "Q5_1", "Q5_K_S", "Q5_K_M",
            "Q6_K", "Q8_0", "F16", "F32"
        ]
        
        for quant in quants {
            if name.contains(quant) {
                return quant
            }
        }
        
        return "Unknown"
    }
    
    private static func extractDownloadDate(from url: URL) -> Date {
        // Try to get file creation date
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let creationDate = attrs[.creationDate] as? Date {
            return creationDate
        }
        return Date()
    }
}
