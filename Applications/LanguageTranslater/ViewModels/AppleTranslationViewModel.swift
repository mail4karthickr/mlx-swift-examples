//
//  AppleTranslationViewModel.swift
//  LanguageTranslater
//
//  ViewModel for Apple Translation framework UI.
//

import Foundation
import SwiftUI

/// ViewModel for Apple Translation framework
@MainActor
@Observable
final class AppleTranslationViewModel {
    
    // MARK: - Dependencies
    
    private let service = AppleTranslationService()
    
    // MARK: - UI State
    
    /// Whether the Translation framework is available
    var isAvailable: Bool { service.isAvailable }
    
    /// Status message
    var availabilityMessage: String { service.availabilityMessage }
    
    /// The translated text
    var translatedText: String { service.translatedText }
    
    /// Error message
    var errorMessage: String? { service.errorMessage }
    
    /// Translation time
    var translationTime: Double? { service.translationTime }
    
    /// Currently selected language
    var selectedLanguage: TargetLanguage = .russian
    
    /// Whether translation is in progress
    var isTranslating: Bool = false
    
    // MARK: - Computed Properties
    
    /// Formatted translation time
    var formattedTranslationTime: String? {
        guard let time = translationTime else { return nil }
        return String(format: "%.2fs", time)
    }
    
    // MARK: - Public Methods
    
    /// Check availability
    func checkAvailability() {
        service.checkAvailability()
    }
    
    /// Start translation - call this when triggering the translation task
    func startTranslation() {
        isTranslating = true
    }
    
    /// Handle successful translation response
    func handleTranslationResponse(_ response: String, time: Double) {
        service.handleTranslationResponse(response, time: time)
        isTranslating = false
    }
    
    /// Handle translation error
    func handleTranslationError(_ error: Error) {
        service.handleTranslationError(error)
        isTranslating = false
    }
    
    /// Clear results
    func clear() {
        service.clear()
        isTranslating = false
    }
}
