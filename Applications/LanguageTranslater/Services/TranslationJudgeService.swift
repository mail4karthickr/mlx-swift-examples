//
//  TranslationJudgeService.swift
//  LanguageTranslater
//
//  A reusable LLM-as-a-Judge service using OpenAI's GPT-5.1 to evaluate translation quality.
//  GPT-5.1 provides excellent multilingual understanding for direct evaluation without
//  needing reverse translation. Uses the MacPaw/OpenAI Swift SDK for API calls.
//

import Foundation
import OpenAI

/// Represents the result of an LLM judge evaluation
struct TranslationJudgement: Sendable {
    /// Overall quality score (1-10)
    let overallScore: Int
    
    /// Score for AFM translation (1-10)
    let afmScore: Int
    
    /// Score for MLX translation (1-10)
    let mlxScore: Int
    
    /// Score for Apple Translation Framework (1-10)
    let appleTranslationScore: Int
    
    /// Which translation is better: "AFM", "MLX", "APPLE_TRANSLATION", or "TIE"
    let winner: String
    
    /// Brief explanation of the evaluation
    let explanation: String
    
    /// Key differences noted between translations
    let keyDifferences: String
    
    /// Raw response from the LLM (for debugging)
    let rawResponse: String
}

/// Error types for the translation judge service
enum TranslationJudgeError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidResponse
    case networkError(String)
    case parsingError(String)
    case timeout
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Please set the OPENAI_API_KEY environment variable."
        case .invalidResponse:
            return "Received an invalid response from the LLM judge."
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Failed to parse judge response: \(message)"
        case .timeout:
            return "Request timed out. Please try again."
        case .maxRetriesExceeded:
            return "Failed after multiple attempts. Please check your connection and try again."
        }
    }
}

/// A reusable service for evaluating translation quality using OpenAI's GPT models
@MainActor
final class TranslationJudgeService: Sendable {
    
    // MARK: - Configuration
    
    /// Maximum number of retry attempts for failed requests
    private static let maxRetries = 3
    
    /// Timeout duration in seconds for each request
    private static let timeoutSeconds: UInt64 = 60
    
    /// Delay between retries (in seconds), doubles with each retry
    private static let baseRetryDelay: UInt64 = 2
    
    // MARK: - Properties
    
    /// The OpenAI client
    private let openAI: OpenAI
    
    /// The model to use for judging (GPT-5.1 recommended for best multilingual evaluation)
    private let model: Model
    
    /// Whether the service is currently evaluating
    private(set) var isEvaluating: Bool = false
    
    /// Last error encountered
    private(set) var errorMessage: String?
    
    /// Last judgement result
    private(set) var lastJudgement: TranslationJudgement?
    
    /// Current retry attempt (for UI feedback)
    private(set) var currentRetryAttempt: Int = 0
    
    // MARK: - Initialization
    
    /// Initialize the service with an API key
    /// - Parameters:
    ///   - apiKey: OpenAI API key (from environment variable OPENAI_API_KEY)
    ///   - model: The model to use for judging (defaults to gpt-4 for best multilingual understanding)
    init(apiKey: String? = nil, model: Model = "gpt-4") {
        // Get API key from parameter or environment variable
        let key = apiKey 
            ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? ""
        
        self.openAI = OpenAI(apiToken: key)
        self.model = model
    }
    
    // MARK: - Public Methods
    
    /// Check if the service is properly configured with an API key
    var isConfigured: Bool {
        guard let token = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            return false
        }
        return !token.isEmpty
    }
    
    /// Evaluate three translations against the source text
    /// - Parameters:
    ///   - sourceText: The original English text
    ///   - afmTranslation: Translation from Apple Foundation Models
    ///   - mlxTranslation: Translation from MLX/Hugging Face (Gemma)
    ///   - appleTranslation: Translation from Apple Translation Framework
    ///   - targetLanguage: The target language for translation
    /// - Returns: A TranslationJudgement with scores and explanation
    func evaluate(
        sourceText: String,
        afmTranslation: String,
        mlxTranslation: String,
        appleTranslation: String,
        targetLanguage: TargetLanguage
    ) async throws -> TranslationJudgement {
        guard isConfigured else {
            throw TranslationJudgeError.missingAPIKey
        }
        
        isEvaluating = true
        errorMessage = nil
        currentRetryAttempt = 0
        
        defer {
            isEvaluating = false
            currentRetryAttempt = 0
        }
        
        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(
            sourceText: sourceText,
            afmTranslation: afmTranslation,
            mlxTranslation: mlxTranslation,
            appleTranslation: appleTranslation,
            targetLanguage: targetLanguage
        )
        
        // Build messages array, filtering out any nil values
        var messages: [ChatQuery.ChatCompletionMessageParam] = []
        if let systemMessage = ChatQuery.ChatCompletionMessageParam(role: .system, content: systemPrompt) {
            messages.append(systemMessage)
        }
        if let userMessage = ChatQuery.ChatCompletionMessageParam(role: .user, content: userPrompt) {
            messages.append(userMessage)
        }
        
        let query = ChatQuery(
            messages: messages,
            model: model,
            temperature: 0.3  // Lower temperature for more consistent evaluations
        )
        
        // Retry loop with exponential backoff
        var lastError: Error?
        
        for attempt in 1...Self.maxRetries {
            currentRetryAttempt = attempt
            
            do {
                // Execute request with timeout
                let judgement = try await executeWithTimeout(query: query)
                lastJudgement = judgement
                return judgement
                
            } catch {
                lastError = error
                
                // Check if error is retryable
                if isRetryableError(error) && attempt < Self.maxRetries {
                    // Calculate delay with exponential backoff
                    let delaySeconds = Self.baseRetryDelay * UInt64(1 << (attempt - 1))
                    try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                    continue
                } else {
                    break
                }
            }
        }
        
        // All retries exhausted
        if let error = lastError as? TranslationJudgeError {
            errorMessage = error.localizedDescription
            throw error
        } else if let error = lastError {
            let networkError = TranslationJudgeError.networkError(error.localizedDescription)
            errorMessage = networkError.localizedDescription
            throw networkError
        } else {
            throw TranslationJudgeError.maxRetriesExceeded
        }
    }
    
    /// Execute the API request with a timeout
    private func executeWithTimeout(query: ChatQuery) async throws -> TranslationJudgement {
        // Create a task that will timeout
        return try await withThrowingTaskGroup(of: TranslationJudgement.self) { group in
            // Add the actual API call task
            group.addTask {
                let result = try await self.openAI.chats(query: query)
                
                guard let content = result.choices.first?.message.content else {
                    throw TranslationJudgeError.invalidResponse
                }
                
                return try self.parseJudgement(from: content)
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: Self.timeoutSeconds * 1_000_000_000)
                throw TranslationJudgeError.timeout
            }
            
            // Wait for first result (either success or timeout)
            guard let result = try await group.next() else {
                throw TranslationJudgeError.invalidResponse
            }
            
            // Cancel remaining tasks
            group.cancelAll()
            
            return result
        }
    }
    
    /// Check if an error is retryable (network issues, timeouts)
    private func isRetryableError(_ error: Error) -> Bool {
        // Timeout errors are retryable
        if let judgeError = error as? TranslationJudgeError {
            switch judgeError {
            case .timeout, .networkError:
                return true
            default:
                return false
            }
        }
        
        // Check for common network error patterns
        let errorDescription = error.localizedDescription.lowercased()
        let retryablePatterns = [
            "timeout",
            "timed out",
            "network",
            "connection",
            "internet",
            "offline",
            "unreachable",
            "reset",
            "502",
            "503",
            "504"
        ]
        
        return retryablePatterns.contains { errorDescription.contains($0) }
    }
    
    /// Clear the last judgement and error
    func clear() {
        lastJudgement = nil
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// Build the system prompt for the judge
    private func buildSystemPrompt() -> String {
        """
        You are an expert translation quality evaluator specializing in banking and financial app translations. Your task is to compare THREE translations of the same source text and provide an objective evaluation.

        TRANSLATION SYSTEMS:
        1. AFM (Apple Foundation Models) - On-device Apple AI model
        2. MLX (MLX/Gemma) - Local Hugging Face model running via MLX
        3. APPLE_TRANSLATION (Apple Translation Framework) - Apple's built-in translation service

        EVALUATION CRITERIA:
        1. **Accuracy**: How well does the translation convey the original meaning?
        2. **Fluency**: How natural does the translation read in the target language?
        3. **Terminology**: Are banking/financial terms translated appropriately?
        4. **Consistency**: Are proper nouns, brand names, and formatting preserved?
        5. **Cultural Appropriateness**: Is the translation suitable for the target audience?

        SCORING GUIDELINES:
        - 9-10: Excellent - Professional quality, ready for production
        - 7-8: Good - Minor issues that don't affect understanding
        - 5-6: Fair - Noticeable issues but still understandable
        - 3-4: Poor - Significant errors affecting comprehension
        - 1-2: Very Poor - Major errors, needs complete rewrite

        RESPONSE FORMAT:
        You MUST respond in the following exact JSON format (no markdown, no code blocks):
        {
            "afm_score": <1-10>,
            "mlx_score": <1-10>,
            "apple_translation_score": <1-10>,
            "overall_score": <1-10>,
            "winner": "<AFM|MLX|APPLE_TRANSLATION|TIE>",
            "explanation": "<brief 1-2 sentence explanation>",
            "key_differences": "<specific differences between the three translations>"
        }

        Be objective, fair, and focus on translation quality rather than stylistic preferences.
        If a translation is marked as "(No translation provided)", give it a score of 0 and don't consider it for winner.
        """
    }
    
    /// Build the user prompt with the translations to compare
    private func buildUserPrompt(
        sourceText: String,
        afmTranslation: String,
        mlxTranslation: String,
        appleTranslation: String,
        targetLanguage: TargetLanguage
    ) -> String {
        """
        Please evaluate the following translations from English to \(targetLanguage.languageName):

        **SOURCE TEXT (English):**
        \(sourceText)

        **AFM TRANSLATION (Apple Foundation Models):**
        \(afmTranslation)

        **MLX TRANSLATION (MLX/Gemma - Hugging Face):**
        \(mlxTranslation)

        **APPLE_TRANSLATION (Apple Translation Framework):**
        \(appleTranslation)

        Evaluate all three translations and provide your assessment in the required JSON format.
        Remember: Use "AFM" for Apple Foundation Models, "MLX" for MLX/Gemma, "APPLE_TRANSLATION" for Apple Translation Framework, or "TIE" if multiple are equal.
        """
    }
    
    /// Parse the LLM response into a TranslationJudgement
    private func parseJudgement(from content: String) throws -> TranslationJudgement {
        // Clean up the response - remove markdown code blocks if present
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code block markers
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw TranslationJudgeError.parsingError("Could not convert response to data")
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            guard let json = json else {
                throw TranslationJudgeError.parsingError("Response is not a valid JSON object")
            }
            
            // Extract values with defaults
            let afmScore = (json["afm_score"] as? Int) ?? 0
            let mlxScore = (json["mlx_score"] as? Int) ?? 0
            let appleTranslationScore = (json["apple_translation_score"] as? Int) ?? 0
            let overallScore = (json["overall_score"] as? Int) ?? ((afmScore + mlxScore + appleTranslationScore) / 3)
            let rawWinner = (json["winner"] as? String) ?? "TIE"
            let explanation = (json["explanation"] as? String) ?? "No explanation provided"
            let keyDifferences = (json["key_differences"] as? String) ?? "No differences noted"
            
            // Normalize winner value to handle variations like "Translation A", "A", etc.
            let winner = normalizeWinner(rawWinner)
            
            return TranslationJudgement(
                overallScore: overallScore,
                afmScore: afmScore,
                mlxScore: mlxScore,
                appleTranslationScore: appleTranslationScore,
                winner: winner,
                explanation: explanation,
                keyDifferences: keyDifferences,
                rawResponse: content
            )
            
        } catch {
            throw TranslationJudgeError.parsingError("JSON parsing failed: \(error.localizedDescription)")
        }
    }
    
    /// Normalize winner string to standard format (AFM, MLX, APPLE_TRANSLATION, or TIE)
    private func normalizeWinner(_ rawWinner: String) -> String {
        let uppercased = rawWinner.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for Apple Translation Framework variations (check first to avoid matching just "APPLE")
        if uppercased.contains("APPLE_TRANSLATION") || 
           uppercased.contains("APPLE TRANSLATION") || 
           uppercased.contains("TRANSLATION FRAMEWORK") ||
           uppercased == "C" || 
           uppercased == "TRANSLATION C" {
            return "APPLE_TRANSLATION"
        }
        
        // Check for AFM variations
        if uppercased.contains("AFM") || 
           uppercased.contains("APPLE FOUNDATION") || 
           uppercased.contains("FOUNDATION MODEL") ||
           uppercased == "A" || 
           uppercased == "TRANSLATION A" {
            return "AFM"
        }
        
        // Check for MLX variations
        if uppercased.contains("MLX") || 
           uppercased.contains("GEMMA") || 
           uppercased.contains("HUGGING") ||
           uppercased == "B" || 
           uppercased == "TRANSLATION B" {
            return "MLX"
        }
        
        // Check for TIE variations
        if uppercased.contains("TIE") || 
           uppercased.contains("EQUAL") || 
           uppercased.contains("DRAW") ||
           uppercased.contains("BOTH") ||
           uppercased.contains("ALL") {
            return "TIE"
        }
        
        // Default to TIE if we can't determine
        return "TIE"
    }
}
