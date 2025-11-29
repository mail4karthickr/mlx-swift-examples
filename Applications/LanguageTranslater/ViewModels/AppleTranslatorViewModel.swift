//
//  AppleTranslatorViewModel.swift
//  LanguageTranslater
//
//  ViewModel for Apple Foundation Models translation - completely independent of Hugging Face.
//

import Foundation
import SwiftUI

/// ViewModel for Apple Foundation Models translation
@Observable
@MainActor
final class AppleTranslatorViewModel {
    
    // MARK: - Dependencies
    
    private let service = AppleFoundationModelService()
    
    // MARK: - UI State
    
    /// The source text to translate (English)
    var sourceText: String = ""
    
    /// The translated output text
    var translatedText: String = ""
    
    /// Currently selected target language
    var selectedLanguage: TargetLanguage = .french
    
    /// Whether translation is in progress
    var isTranslating: Bool = false
    
    /// Whether Apple Foundation Models are available
    var isAvailable: Bool = false
    
    /// Whether the model is warming up
    var isWarmingUp: Bool = false
    
    /// Whether the model has been warmed up
    var isWarmedUp: Bool = false
    
    /// Availability message to display
    var availabilityMessage: String = "Checking availability..."
    
    /// Error message to display
    var errorMessage: String?
    
    /// Time to first token in seconds
    var timeToFirstToken: Double?
    
    /// Total translation time in seconds
    var totalTranslationTime: Double?
    
    // MARK: - Initialization
    
    init() {
        // Sync state from service
        Task {
            await checkAvailability()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if Apple Foundation Models are available
    func checkAvailability() async {
        await service.checkAvailability()
        syncFromService()
    }
    
    /// Warm up the model to reduce first translation latency
    /// Call this early (e.g., on app launch or view appear) for better UX
    func warmUp() async {
        await service.warmUp()
        syncFromService()
    }
    
    /// Translate the source text to the selected target language
    func translate() async {
        guard !sourceText.isEmpty else {
            errorMessage = "Please enter text to translate"
            return
        }
        
        guard isAvailable else {
            errorMessage = "Apple Foundation Models not available"
            return
        }
        
        isTranslating = true
        translatedText = ""
        errorMessage = nil
        timeToFirstToken = nil
        totalTranslationTime = nil
        
        // Use callback-based streaming for real-time UI updates
        await service.translate(
            text: sourceText,
            to: selectedLanguage
        ) { [weak self] partialResult in
            // This callback is called for each streamed chunk
            self?.translatedText = partialResult
            self?.timeToFirstToken = self?.service.timeToFirstToken
        }
        
        // Final sync after completion
        syncFromService()
        isTranslating = false
    }
    
    /// Clear the input and output
    func clearInput() {
        sourceText = ""
        translatedText = ""
        errorMessage = nil
        timeToFirstToken = nil
        totalTranslationTime = nil
        service.clear()
    }
    
    /// Cancel the current translation
    func cancelTranslation() {
        service.cancelTranslation()
        isTranslating = false
    }
    
    // MARK: - Private Methods
    
    /// Sync state from the service
    private func syncFromService() {
        isAvailable = service.isAvailable
        isWarmingUp = service.isWarmingUp
        isWarmedUp = service.isWarmedUp
        availabilityMessage = service.availabilityMessage
        translatedText = service.translatedText
        errorMessage = service.errorMessage
        timeToFirstToken = service.timeToFirstToken
        totalTranslationTime = service.totalTranslationTime
    }
}
