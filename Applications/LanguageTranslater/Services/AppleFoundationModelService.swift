//
//  AppleFoundationModelService.swift
//  LanguageTranslater
//
//  Service for translation using Apple Foundation Models (iOS 26+/macOS 26+)
//

import Foundation
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Result of an Apple Foundation Models translation
struct AppleTranslationResult {
    var text: String
    var timeToFirstToken: Double?
    var totalTime: Double?
}

/// Availability status for Apple Foundation Models
enum AppleFoundationModelAvailability {
    case available
    case unavailable(reason: String)
    case notSupported
}

/// Service that handles translation using Apple Foundation Models
@MainActor
final class AppleFoundationModelService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAvailable: Bool = false
    @Published var availabilityMessage: String = "Checking availability..."
    @Published var isTranslating: Bool = false
    @Published var translatedText: String = ""
    @Published var errorMessage: String?
    @Published var timeToFirstToken: Double?
    @Published var totalTranslationTime: Double?
    @Published var isWarmingUp: Bool = false
    @Published var isWarmedUp: Bool = false
    
    // MARK: - Private Properties
    
    // Note: We create fresh sessions for each translation to avoid context length issues
    
    // MARK: - Initialization
    
    init() {
        Task {
            await checkAvailability()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if Apple Foundation Models are available on this device
    func checkAvailability() async {
        #if canImport(FoundationModels)
        let availability = SystemLanguageModel.default.availability
        
        switch availability {
        case .available:
            isAvailable = true
            availabilityMessage = "Apple Intelligence Ready"
            
        case .unavailable:
            isAvailable = false
            // Provide a general message since specific reason requires deeper introspection
            availabilityMessage = "Apple Intelligence is not available. Please ensure Apple Intelligence is enabled in Settings > Apple Intelligence & Siri."
            
        @unknown default:
            isAvailable = false
            availabilityMessage = "Unknown availability status"
        }
        #else
        isAvailable = false
        availabilityMessage = "Requires iOS 26+ / macOS 26+"
        #endif
    }
    
    /// Warm up the model by sending a small request
    /// Call this early (e.g., on app launch) to reduce latency for the first real translation
    func warmUp() async {
        #if canImport(FoundationModels)
        guard isAvailable, !isWarmedUp else { return }
        
        isWarmingUp = true
        availabilityMessage = "Warming up Apple Intelligence..."
        
        do {
            // Send a minimal prompt to trigger model loading using a fresh session
            let warmupSession = LanguageModelSession()
            let _ = try await warmupSession.respond(to: "Hi")
            isWarmedUp = true
            availabilityMessage = "Apple Intelligence Ready"
        } catch {
            // Warm-up failed, but that's okay - first real request will just be slower
            availabilityMessage = "Apple Intelligence Ready"
        }
        
        isWarmingUp = false
        #endif
    }
    
    /// Translate text using Apple Foundation Models with streaming callback
    func translate(
        text: String,
        to targetLanguage: TargetLanguage,
        onPartialResult: @escaping (String) -> Void
    ) async {
        #if canImport(FoundationModels)
        guard isAvailable else {
            errorMessage = "Apple Foundation Models not available"
            return
        }
        
        // Create a fresh session for each translation to avoid context length issues
        // This ensures clean state and prevents accumulation of previous conversations
        let translationSession = LanguageModelSession()
        
        isTranslating = true
        translatedText = ""
        errorMessage = nil
        timeToFirstToken = nil
        totalTranslationTime = nil
        
        let startTime = Date()
        var firstTokenReceived = false
        
        do {
            let translationPrompt = TranslationPrompt(text: text, targetLanguage: targetLanguage)
            
            // Use streaming for real-time updates
            let stream = translationSession.streamResponse(to: Prompt(translationPrompt.fullPrompt))
            
            for try await partialResponse in stream {
                if !firstTokenReceived {
                    firstTokenReceived = true
                    timeToFirstToken = Date().timeIntervalSince(startTime)
                }
                
                // Update internal state and call the callback for real-time UI updates
                translatedText = partialResponse.content
                onPartialResult(partialResponse.content)
            }
            
            totalTranslationTime = Date().timeIntervalSince(startTime)
            
            // Clean up the translation using the shared prompt utility
            translatedText = translationPrompt.cleanOutput(translatedText)
            onPartialResult(translatedText)
            
        } catch {
            errorMessage = "Translation failed: \(error.localizedDescription)"
        }
        
        isTranslating = false
        #else
        errorMessage = "Apple Foundation Models not available on this platform"
        #endif
    }
    
    /// Cancel the current translation
    func cancelTranslation() {
        // Note: LanguageModelSession doesn't have a direct cancel method
        // The task will complete or fail naturally
        isTranslating = false
    }
    
    /// Clear translation results
    func clear() {
        translatedText = ""
        errorMessage = nil
        timeToFirstToken = nil
        totalTranslationTime = nil
    }
}
