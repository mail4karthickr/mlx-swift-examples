//
//  TranslationPrompt.swift
//  LanguageTranslater
//
//  A reusable translation prompt builder for consistent prompts across all translation engines.
//

import Foundation

/// A reusable struct for building translation prompts
/// Used by both Apple Foundation Models and MLX/Hugging Face translation services
struct TranslationPrompt {
    
    // MARK: - Properties
    
    /// The source text to translate
    let sourceText: String
    
    /// The target language for translation
    let targetLanguage: TargetLanguage
    
    // MARK: - Initialization
    
    init(text: String, targetLanguage: TargetLanguage) {
        self.sourceText = text
        self.targetLanguage = targetLanguage
    }
    
    // MARK: - System Prompt (for chat-based models like Gemma)
    
    /// The system prompt for banking app translation context
    static var systemPrompt: String {
        """
        You are an expert language translator for a banking mobile app, specialized in translating English to Chinese, Vietnamese, French, and Russian.

        CRITICAL RULES:
        1. NEVER translate: bank names, company names, brand names, product names, or any proper nouns - keep them EXACTLY as written
        2. ONLY translate the language - do NOT add, remove, or modify any content
        3. Preserve meaning and intent over literal word-for-word translation
        4. Keep exact formatting, structure, numbers, symbols, and punctuation unchanged
        5. Output ONLY the translated text - no explanations or commentary
        """
    }
    
    // MARK: - User Prompts
    
    /// The user prompt for chat-based models (simpler, used with system prompt)
    var userPrompt: String {
        """
        Translate the following text from English to \(targetLanguage.languageName):

        \(sourceText)
        """
    }
    
    /// The full translation prompt (includes context, for single-turn models like Apple Foundation Models)
    var fullPrompt: String {
        """
        You are an expert language translator for a banking mobile app, specialized in translating English to \(targetLanguage.languageName).

        CRITICAL RULES:
        1. NEVER translate: bank names, company names, brand names, product names, or any proper nouns - keep them EXACTLY as written
        2. ONLY translate the language - do NOT add, remove, or modify any content
        3. Preserve meaning and intent over literal word-for-word translation
        4. Keep exact formatting, structure, numbers, symbols, and punctuation unchanged
        5. Output ONLY the translated text - no explanations or commentary

        Translate the following text from English to \(targetLanguage.languageName):

        \(sourceText)
        """
    }
    
    // MARK: - Output Cleaning
    
    /// Common prefixes that models might add to their output
    private var prefixesToRemove: [String] {
        [
            "Translation:",
            "Here is the translation:",
            "The translation is:",
            "In \(targetLanguage.languageName):",
            "\(targetLanguage.languageName):",
        ]
    }
    
    /// Clean up the translation output by removing common prefixes
    /// - Parameter text: The raw translation output from the model
    /// - Returns: The cleaned translation text
    func cleanOutput(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for prefix in prefixesToRemove {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return cleaned
    }
}
