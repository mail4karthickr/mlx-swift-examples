//
//  TranslationService.swift
//  LanguageTranslater
//
//  Handles the translation logic using MLX models.
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom

/// Result of a translation operation
struct TranslationResult {
    var text: String
    var timeToFirstToken: Double?
    var totalTime: Double?
    var tokensPerSecond: Double?
}

/// Protocol for translation progress updates
protocol TranslationDelegate: AnyObject {
    @MainActor func translationDidStart()
    @MainActor func translationDidReceiveChunk(_ chunk: String)
    @MainActor func translationDidUpdateStats(tokensPerSecond: Double)
    @MainActor func translationDidUpdateTimeToFirstToken(_ time: Double)
    @MainActor func translationDidComplete(result: TranslationResult)
    @MainActor func translationDidFail(error: Error)
    @MainActor func translationDidCancel()
}

/// Service that handles translation using MLX models
actor TranslationService {
    
    // MARK: - Properties
    
    private var currentTask: Task<Void, Error>?
    
    private let generateParameters = GenerateParameters(
        maxTokens: 512,
        temperature: 0.3  // Lower temperature for more accurate translations
    )
    
    // MARK: - Public Methods
    
    /// Translate text to the target language
    func translate(
        text: String,
        to targetLanguage: TargetLanguage,
        using container: ModelContainer,
        delegate: TranslationDelegate?
    ) async {
        // Cancel any existing translation
        currentTask?.cancel()
        
        await delegate?.translationDidStart()
        
        let translationStartTime = Date()
        var translatedText = ""
        var timeToFirstToken: Double?
        var tokensPerSecond: Double?
        
        currentTask = Task {
            do {
                let translationPrompt = TranslationPrompt(text: text, targetLanguage: targetLanguage)
                
                let chat: [Chat.Message] = [
                    .system(TranslationPrompt.systemPrompt),
                    .user(translationPrompt.userPrompt)
                ]
                
                let userInput = UserInput(chat: chat)
                
                // Seed random for reproducibility
                MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
                
                var firstTokenReceived = false
                
                try await container.perform { [weak delegate] (context: ModelContext) in
                    let lmInput = try await context.processor.prepare(input: userInput)
                    let stream = try MLXLMCommon.generate(
                        input: lmInput,
                        parameters: self.generateParameters,
                        context: context
                    )
                    
                    for await generation in stream {
                        try Task.checkCancellation()
                        
                        switch generation {
                        case .chunk(let chunk):
                            if !firstTokenReceived {
                                firstTokenReceived = true
                                let ttft = Date().timeIntervalSince(translationStartTime)
                                timeToFirstToken = ttft
                                await delegate?.translationDidUpdateTimeToFirstToken(ttft)
                            }
                            translatedText += chunk
                            await delegate?.translationDidReceiveChunk(chunk)
                            
                        case .info(let info):
                            tokensPerSecond = info.tokensPerSecond
                            await delegate?.translationDidUpdateStats(tokensPerSecond: info.tokensPerSecond)
                            
                        case .toolCall(_):
                            break
                        }
                    }
                }
                
                let totalTime = Date().timeIntervalSince(translationStartTime)
                let translationPromptForClean = TranslationPrompt(text: text, targetLanguage: targetLanguage)
                let cleanedText = translationPromptForClean.cleanOutput(translatedText)
                
                let result = TranslationResult(
                    text: cleanedText,
                    timeToFirstToken: timeToFirstToken,
                    totalTime: totalTime,
                    tokensPerSecond: tokensPerSecond
                )
                
                await delegate?.translationDidComplete(result: result)
                
            } catch is CancellationError {
                await delegate?.translationDidCancel()
            } catch {
                await delegate?.translationDidFail(error: error)
            }
        }
        
        try? await currentTask?.value
    }
    
    /// Cancel the current translation
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}
