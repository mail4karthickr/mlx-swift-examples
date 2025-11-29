//
//  TranslatorViewModel.swift
//  LanguageTranslater
//
//  ViewModel that coordinates translation UI state and services.
//

import Foundation
import SwiftUI

/// ViewModel that manages the translation UI and coordinates services
@Observable
@MainActor
final class TranslatorViewModel: TranslationDelegate {
    
    // MARK: - Dependencies
    
    private let modelManager = ModelManager.shared
    private let translationService = TranslationService()
    
    // MARK: - UI State
    
    /// The source text to translate (English)
    var sourceText: String = ""
    
    /// The translated output text
    var translatedText: String = ""
    
    /// Currently selected target language
    var selectedLanguage: TargetLanguage = .french
    
    /// Whether the model settings sheet is shown
    var isModelSettingsPresented: Bool = false
    
    /// Whether translation is in progress
    var isTranslating: Bool = false
    
    /// Error message to display
    var errorMessage: String?
    
    /// Translation performance stats (tokens/s)
    var translationStats: String?
    
    /// Time to first token in seconds
    var timeToFirstToken: Double?
    
    /// Total translation time in seconds
    var totalTranslationTime: Double?
    
    // MARK: - Computed Properties (delegated to ModelManager)
    
    var availableMLXModels: [MLXTranslationModel] {
        modelManager.availableModels
    }
    
    var selectedMLXModel: MLXTranslationModel? {
        modelManager.selectedModel
    }
    
    var isModelLoaded: Bool {
        modelManager.isModelReady
    }
    
    var isLoadingModel: Bool {
        modelManager.isLoadingModel
    }
    
    var modelInfo: String? {
        modelManager.loadingStatus
    }
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Check which models are already downloaded
    func checkDownloadedModels() async {
        await modelManager.checkDownloadedModels()
    }
    
    /// Select a model for translation
    func selectModel(_ model: MLXTranslationModel) async {
        await modelManager.selectModel(model)
    }
    
    /// Download a specific model
    func downloadModel(_ model: MLXTranslationModel) async {
        await modelManager.downloadModel(model)
    }
    
    /// Delete a downloaded model
    func deleteModel(_ model: MLXTranslationModel) async {
        await modelManager.deleteModel(model)
    }
    
    /// Load the selected model
    func loadSelectedModel() async {
        await modelManager.loadSelectedModel()
    }
    
    /// Translate the source text to the selected target language
    func translate() async {
        print("🔄 Translate called")
        
        guard !sourceText.isEmpty else {
            print("❌ Source text is empty")
            return
        }
        
        guard let container = modelManager.modelContainer else {
            print("❌ Model container is nil")
            errorMessage = "Please download and select a model first"
            return
        }
        
        print("✅ Starting translation...")
        
        await translationService.translate(
            text: sourceText,
            to: selectedLanguage,
            using: container,
            delegate: self
        )
    }
    
    /// Clear the input and output text
    func clearInput() {
        sourceText = ""
        translatedText = ""
        translationStats = nil
        timeToFirstToken = nil
        totalTranslationTime = nil
    }
    
    /// Cancel the current translation
    func cancelTranslation() async {
        await translationService.cancel()
        isTranslating = false
    }
    
    // MARK: - TranslationDelegate
    
    func translationDidStart() {
        isTranslating = true
        translatedText = ""
        translationStats = nil
        timeToFirstToken = nil
        totalTranslationTime = nil
    }
    
    func translationDidReceiveChunk(_ chunk: String) {
        translatedText += chunk
    }
    
    func translationDidUpdateStats(tokensPerSecond: Double) {
        translationStats = String(format: "%.1f tokens/s", tokensPerSecond)
    }
    
    func translationDidUpdateTimeToFirstToken(_ time: Double) {
        timeToFirstToken = time
    }
    
    func translationDidComplete(result: TranslationResult) {
        translatedText = result.text
        totalTranslationTime = result.totalTime
        if let tps = result.tokensPerSecond {
            translationStats = String(format: "%.1f tokens/s", tps)
        }
        isTranslating = false
    }
    
    func translationDidFail(error: Error) {
        errorMessage = "Translation failed: \(error.localizedDescription)"
        isTranslating = false
    }
    
    func translationDidCancel() {
        translatedText += "\n[Cancelled]"
        isTranslating = false
    }
}
