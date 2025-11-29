//
//  AppleTranslationService.swift
//  LanguageTranslater
//
//  Service for translation using Apple's Translation framework (iOS 17.4+/macOS 14.4+)
//  This uses Apple's built-in translation engine, not the on-device LLM.
//  Reference: https://developer.apple.com/documentation/translation/
//
//  Uses .translationPresentation modifier which shows Apple's built-in translation UI.
//

import Foundation
import SwiftUI

/// Service that handles translation using Apple's Translation framework
@MainActor
@Observable
final class AppleTranslationService {
    
    // MARK: - Properties
    
    /// Whether the Translation framework is available
    var isAvailable: Bool = false
    
    /// Status message for availability
    var availabilityMessage: String = "Checking availability..."
    
    /// The translated text result
    var translatedText: String = ""
    
    /// Error message if translation fails
    var errorMessage: String?
    
    /// Time taken for translation
    var translationTime: Double?
    
    /// The target language for translation
    var targetLanguage: TargetLanguage = .russian
    
    // MARK: - Initialization
    
    init() {
        checkAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Check if Translation framework is available
    func checkAvailability() {
        #if canImport(Translation)
        if #available(iOS 17.4, macOS 14.4, *) {
            isAvailable = true
            availabilityMessage = "Apple Translation Ready"
        } else {
            isAvailable = false
            availabilityMessage = "Requires iOS 17.4+ / macOS 14.4+"
        }
        #else
        isAvailable = false
        availabilityMessage = "Translation framework not available"
        #endif
    }
    
    /// Called when translation completes successfully
    func handleTranslationResponse(_ response: String, time: Double) {
        translatedText = response
        translationTime = time
        errorMessage = nil
    }
    
    /// Called when translation fails
    func handleTranslationError(_ error: Error) {
        errorMessage = "Translation failed: \(error.localizedDescription)"
    }
    
    /// Clear translation results
    func clear() {
        translatedText = ""
        errorMessage = nil
        translationTime = nil
    }
}
