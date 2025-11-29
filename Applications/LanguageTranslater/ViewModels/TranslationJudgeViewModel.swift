//
//  TranslationJudgeViewModel.swift
//  LanguageTranslater
//
//  ViewModel for the LLM-as-a-Judge translation quality evaluator.
//

import Foundation
import SwiftUI

/// ViewModel for the Translation Judge feature
@Observable
@MainActor
final class TranslationJudgeViewModel {
    
    // MARK: - Dependencies
    
    private let service: TranslationJudgeService
    
    // MARK: - UI State
    
    /// Whether evaluation is in progress
    var isEvaluating: Bool = false
    
    /// Whether the service is properly configured with an API key
    var isConfigured: Bool = false
    
    /// The last judgement result
    var judgement: TranslationJudgement?
    
    /// Error message to display
    var errorMessage: String?
    
    /// Whether to show detailed results
    var showDetailedResults: Bool = false
    
    /// Current retry attempt (for UI feedback)
    var currentRetryAttempt: Int { service.currentRetryAttempt }
    
    // MARK: - Computed Properties
    
    /// Get the winner display text with emoji
    var winnerDisplay: String {
        guard let judgement = judgement else { return "" }
        
        switch judgement.winner.uppercased() {
        case "AFM":
            return "🍎 Apple Foundation Models"
        case "MLX":
            return "🤗 MLX/Gemma"
        case "APPLE_TRANSLATION":
            return "🌐 Apple Translation"
        case "TIE":
            return "🤝 Tie"
        default:
            return judgement.winner
        }
    }
    
    /// Get a color for the winner badge
    var winnerColor: Color {
        guard let judgement = judgement else { return .secondary }
        
        switch judgement.winner.uppercased() {
        case "AFM":
            return .blue
        case "MLX":
            return .orange
        case "APPLE_TRANSLATION":
            return .green
        case "TIE":
            return .purple
        default:
            return .secondary
        }
    }
    
    /// Get color for AFM score
    var afmScoreColor: Color {
        guard let judgement = judgement else { return .secondary }
        return scoreColor(for: judgement.afmScore)
    }
    
    /// Get color for MLX score
    var mlxScoreColor: Color {
        guard let judgement = judgement else { return .secondary }
        return scoreColor(for: judgement.mlxScore)
    }
    
    /// Get color for Apple Translation score
    var appleTranslationScoreColor: Color {
        guard let judgement = judgement else { return .secondary }
        return scoreColor(for: judgement.appleTranslationScore)
    }
    
    // MARK: - Initialization
    
    init(apiKey: String? = nil) {
        self.service = TranslationJudgeService(apiKey: apiKey)
        self.isConfigured = service.isConfigured
    }
    
    // MARK: - Public Methods
    
    /// Evaluate three translations
    /// - Parameters:
    ///   - sourceText: The original English text
    ///   - afmTranslation: Translation from Apple Foundation Models
    ///   - mlxTranslation: Translation from MLX/Hugging Face
    ///   - appleTranslation: Translation from Apple Translation Framework
    ///   - targetLanguage: The target language
    func evaluate(
        sourceText: String,
        afmTranslation: String,
        mlxTranslation: String,
        appleTranslation: String,
        targetLanguage: TargetLanguage
    ) async {
        // Validate inputs
        guard !sourceText.isEmpty else {
            errorMessage = "Please enter source text to translate first"
            return
        }
        
        guard !afmTranslation.isEmpty || !mlxTranslation.isEmpty || !appleTranslation.isEmpty else {
            errorMessage = "Please generate at least one translation before evaluating"
            return
        }
        
        guard isConfigured else {
            errorMessage = "OpenAI API key not configured. Set OPENAI_API_KEY environment variable."
            return
        }
        
        isEvaluating = true
        errorMessage = nil
        judgement = nil
        
        do {
            let result = try await service.evaluate(
                sourceText: sourceText,
                afmTranslation: afmTranslation.isEmpty ? "(No translation provided)" : afmTranslation,
                mlxTranslation: mlxTranslation.isEmpty ? "(No translation provided)" : mlxTranslation,
                appleTranslation: appleTranslation.isEmpty ? "(No translation provided)" : appleTranslation,
                targetLanguage: targetLanguage
            )
            
            judgement = result
            isEvaluating = false
            
        } catch {
            errorMessage = error.localizedDescription
            isEvaluating = false
        }
    }
    
    /// Clear the judgement and error
    func clear() {
        judgement = nil
        errorMessage = nil
        service.clear()
    }
    
    /// Check if API key is configured
    func refreshConfiguration() {
        isConfigured = service.isConfigured
    }
    
    // MARK: - Private Methods
    
    /// Get a color based on the score value
    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 9...10:
            return .green
        case 7...8:
            return .blue
        case 5...6:
            return .orange
        case 3...4:
            return .red
        default:
            return .red
        }
    }
}
