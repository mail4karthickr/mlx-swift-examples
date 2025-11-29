//
//  ModelManager.swift
//  LanguageTranslater
//
//  Manages MLX model detection, downloading, deletion, and caching.
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon

/// Represents an available MLX model for translation
struct MLXTranslationModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let size: String
    let configuration: ModelConfiguration
    var isDownloaded: Bool = false
    var isDownloading: Bool = false
    var downloadProgress: Double = 0
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MLXTranslationModel, rhs: MLXTranslationModel) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages MLX model lifecycle: detection, downloading, deletion, and caching
@Observable
@MainActor
final class ModelManager {
    
    // MARK: - Singleton
    
    static let shared = ModelManager()
    
    // MARK: - Available Models
    
    /// List of available MLX models for translation
    var availableModels: [MLXTranslationModel] = [
        MLXTranslationModel(
            id: "gemma3n-e2b",
            displayName: "Gemma 3n E2B IT LM 4-bit",
            size: "~1.5 GB",
            configuration: LLMRegistry.gemma3n_E2B_it_lm_4bit
        ),
        MLXTranslationModel(
            id: "gemma3n-e4b",
            displayName: "Gemma 3n E4B IT LM 4-bit",
            size: "~2.5 GB",
            configuration: LLMRegistry.gemma3n_E4B_it_lm_4bit
        )
    ]
    
    // MARK: - State
    
    /// Currently selected model
    var selectedModel: MLXTranslationModel?
    
    /// Whether a model is currently being loaded
    var isLoadingModel: Bool = false
    
    /// Current loading status message
    var loadingStatus: String?
    
    /// Whether the selected model is loaded and ready
    var isModelReady: Bool = false
    
    /// Error message if any operation fails
    var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// Cache of loaded model containers by model ID
    private static var modelCache: [String: ModelContainer] = [:]
    
    /// Track which models are currently being loaded to prevent duplicate loads
    private static var modelsCurrentlyLoading: Set<String> = []
    
    /// Flag to prevent concurrent model checks
    private var isCheckingModels = false
    
    /// The currently loaded model container
    private(set) var modelContainer: ModelContainer?
    
    /// Current download task
    private var downloadTask: Task<Void, Error>?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check which models are already downloaded
    func checkDownloadedModels() async {
        guard !isCheckingModels else {
            print("⏳ Already checking models, skipping...")
            return
        }
        
        isCheckingModels = true
        print("🔍 Starting checkDownloadedModels()")
        
        let modelsToCheck = availableModels.map { $0.configuration.name }
        
        // Run file system checks on a background thread
        let results: [(Int, Bool)] = await Task.detached { [weak self] in
            guard let self = self else { return [] }
            var modelStates: [(Int, Bool)] = []
            for (index, modelName) in modelsToCheck.enumerated() {
                let isDownloaded = self.isModelDownloadedSync(modelName: modelName)
                modelStates.append((index, isDownloaded))
            }
            return modelStates
        }.value
        
        // Update state on main thread
        for (index, isDownloaded) in results {
            let model = availableModels[index]
            availableModels[index].isDownloaded = isDownloaded
            
            print("  Model: \(model.displayName) - isDownloaded: \(isDownloaded)")
            
            if isDownloaded {
                availableModels[index].isDownloading = false
                availableModels[index].downloadProgress = 1.0
            } else {
                availableModels[index].isDownloading = false
                availableModels[index].downloadProgress = 0.0
            }
        }
        
        // Auto-select default model
        selectDefaultModel()
        
        // Auto-load the selected model
        if let selectedModel = selectedModel, selectedModel.isDownloaded {
            print("🔄 Auto-loading selected model: \(selectedModel.displayName)")
            await loadSelectedModel()
        }
        
        isCheckingModels = false
        print("✅ Finished checkDownloadedModels()")
    }
    
    /// Select a model for use
    func selectModel(_ model: MLXTranslationModel) async {
        selectedModel = model
        
        if model.isDownloaded {
            await loadSelectedModel()
        } else {
            modelContainer = nil
            isModelReady = false
            loadingStatus = nil
        }
    }
    
    /// Load the selected model (if already downloaded)
    func loadSelectedModel() async {
        guard let model = selectedModel, model.isDownloaded else {
            print("⚠️ Cannot load model - selected: \(selectedModel?.displayName ?? "none"), downloaded: \(selectedModel?.isDownloaded ?? false)")
            return
        }
        
        // Check if model is already in cache
        if let cachedContainer = Self.modelCache[model.id] {
            print("✅ Using cached model container for: \(model.displayName)")
            modelContainer = cachedContainer
            isModelReady = true
            loadingStatus = nil
            return
        }
        
        // Check if this model is already being loaded
        if Self.modelsCurrentlyLoading.contains(model.id) {
            print("⏳ Model already loading, waiting: \(model.displayName)")
            while Self.modelsCurrentlyLoading.contains(model.id) {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            if let cachedContainer = Self.modelCache[model.id] {
                modelContainer = cachedContainer
                isModelReady = true
                loadingStatus = nil
            }
            return
        }
        
        // Mark as loading
        Self.modelsCurrentlyLoading.insert(model.id)
        isLoadingModel = true
        loadingStatus = "Loading \(model.displayName)..."
        print("📦 Starting to load model: \(model.displayName)")
        
        // Load model on background thread
        let modelConfig = model.configuration
        let modelId = model.id
        
        let loadResult: Result<ModelContainer, Error> = await Task.detached(priority: .userInitiated) {
            do {
                MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)
                print("🔄 Loading model from disk (background thread)...")
                let container = try await LLMModelFactory.shared.loadContainer(
                    configuration: modelConfig
                ) { _ in }
                return .success(container)
            } catch {
                return .failure(error)
            }
        }.value
        
        // Update state on main thread
        switch loadResult {
        case .success(let container):
            Self.modelCache[modelId] = container
            Self.modelsCurrentlyLoading.remove(modelId)
            modelContainer = container
            isModelReady = true
            isLoadingModel = false
            loadingStatus = nil
            print("✅ Model loaded and cached: \(model.displayName)")
            
        case .failure(let error):
            Self.modelsCurrentlyLoading.remove(modelId)
            isLoadingModel = false
            loadingStatus = "Model loading failed"
            errorMessage = "Failed to load model: \(error.localizedDescription)"
            print("❌ Failed to load model: \(error.localizedDescription)")
        }
    }
    
    /// Download a specific model
    func downloadModel(_ model: MLXTranslationModel) async {
        guard let index = availableModels.firstIndex(where: { $0.id == model.id }) else { return }
        
        downloadTask?.cancel()
        
        availableModels[index].isDownloading = true
        availableModels[index].downloadProgress = 0
        
        downloadTask = Task {
            do {
                MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)
                
                let container = try await LLMModelFactory.shared.loadContainer(
                    configuration: model.configuration
                ) { [weak self] progress in
                    Task { @MainActor in
                        guard let self = self,
                              let idx = self.availableModels.firstIndex(where: { $0.id == model.id }) else { return }
                        let cappedProgress = min(progress.fractionCompleted, 0.95)
                        self.availableModels[idx].downloadProgress = cappedProgress
                    }
                }
                
                print("✅ Download completed for \(model.displayName)")
                
                // Cache the downloaded container
                Self.modelCache[model.id] = container
                
                // Re-check models to update state
                await self.checkDownloadedModels()
                
                // If this is the selected model, set the container
                if self.selectedModel?.id == model.id {
                    self.modelContainer = container
                    self.isModelReady = true
                    self.loadingStatus = nil
                }
                
            } catch {
                if let idx = self.availableModels.firstIndex(where: { $0.id == model.id }) {
                    self.availableModels[idx].isDownloading = false
                    self.availableModels[idx].downloadProgress = 0
                }
                self.errorMessage = "Download failed: \(error.localizedDescription)"
            }
        }
        
        try? await downloadTask?.value
    }
    
    /// Delete a downloaded model
    func deleteModel(_ model: MLXTranslationModel) async {
        guard model.isDownloaded else { return }
        
        let fileManager = FileManager.default
        let modelName = model.configuration.name
        
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            errorMessage = "Could not access cache directory"
            return
        }
        
        let modelPath = cachesDir.appendingPathComponent("models/\(modelName)")
        print("🗑️ Attempting to delete model at: \(modelPath.path)")
        
        do {
            if fileManager.fileExists(atPath: modelPath.path) {
                try fileManager.removeItem(at: modelPath)
                print("✅ Successfully deleted model from: \(modelPath.path)")
            } else {
                print("⚠️ No model files found to delete at: \(modelPath.path)")
            }
            
            // Clear from cache
            Self.modelCache.removeValue(forKey: model.id)
            
            // Update model state
            if let idx = availableModels.firstIndex(where: { $0.id == model.id }) {
                availableModels[idx].isDownloaded = false
                availableModels[idx].downloadProgress = 0
            }
            
            // If this was the selected model, clear the selection
            if selectedModel?.id == model.id {
                modelContainer = nil
                isModelReady = false
                selectedModel = nil
                loadingStatus = nil
            }
            
        } catch {
            errorMessage = "Failed to delete model: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Methods
    
    /// Select the default model (first downloaded one)
    private func selectDefaultModel() {
        if let defaultModel = availableModels.first(where: { $0.id == "gemma3n-e2b" && $0.isDownloaded }) {
            selectedModel = defaultModel
        } else if let firstDownloaded = availableModels.first(where: { $0.isDownloaded }) {
            selectedModel = firstDownloaded
        } else {
            selectedModel = nil
        }
    }
    
    /// Check if a model is downloaded (synchronous, for background thread)
    private nonisolated func isModelDownloadedSync(modelName: String) -> Bool {
        let fileManager = FileManager.default
        
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return false
        }
        
        let modelPath = cachesDir.appendingPathComponent("models/\(modelName)")
        
        guard fileManager.fileExists(atPath: modelPath.path) else {
            return false
        }
        
        return hasRequiredModelFiles(at: modelPath, fileManager: fileManager)
    }
    
    /// Check if directory contains required model files
    private nonisolated func hasRequiredModelFiles(at url: URL, fileManager: FileManager) -> Bool {
        // Check for snapshots directory
        let snapshotsPath = url.appendingPathComponent("snapshots")
        if fileManager.fileExists(atPath: snapshotsPath.path) {
            if let snapshots = try? fileManager.contentsOfDirectory(atPath: snapshotsPath.path), !snapshots.isEmpty {
                for snapshot in snapshots {
                    let snapshotPath = snapshotsPath.appendingPathComponent(snapshot)
                    if checkModelFiles(at: snapshotPath, fileManager: fileManager) {
                        return true
                    }
                }
            }
            return false
        }
        
        return checkModelFiles(at: url, fileManager: fileManager)
    }
    
    /// Check for config.json and weight files
    private nonisolated func checkModelFiles(at url: URL, fileManager: FileManager) -> Bool {
        guard let files = try? fileManager.contentsOfDirectory(atPath: url.path) else {
            return false
        }
        
        let hasConfig = files.contains("config.json")
        let hasWeights = files.contains { $0.hasSuffix(".safetensors") || $0.hasSuffix(".bin") }
            || files.contains("model.safetensors.index.json")
        
        return hasConfig && hasWeights
    }
}
