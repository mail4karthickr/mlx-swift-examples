//
//  TranslationJudgeView.swift
//  LanguageTranslater
//
//  SwiftUI view for the LLM-as-a-Judge translation quality comparison.
//

import SwiftUI

/// A view that displays the LLM judge's evaluation of translations
struct TranslationJudgeView: View {
    
    // MARK: - Properties
    
    @Bindable var viewModel: TranslationJudgeViewModel
    
    /// Source text to evaluate
    let sourceText: String
    
    /// AFM translation to evaluate
    let afmTranslation: String
    
    /// MLX translation to evaluate
    let mlxTranslation: String
    
    /// Apple Translation Framework translation to evaluate
    let appleTranslation: String
    
    /// Target language
    let targetLanguage: TargetLanguage
    
    /// Whether comparison is enabled (at least 2 translations available and none in progress)
    var canCompare: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView
            
            // Content
            if !viewModel.isConfigured {
                notConfiguredView
            } else if viewModel.isEvaluating {
                evaluatingView
            } else if let judgement = viewModel.judgement {
                resultsView(judgement: judgement)
            } else {
                readyToEvaluateView
            }
            
            // Error message
            if let error = viewModel.errorMessage {
                errorView(error: error)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Image(systemName: "scale.3d")
                .font(.title2)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("LLM Judge")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Powered by OpenAI GPT-5.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Evaluate button
            if viewModel.isConfigured && !viewModel.isEvaluating {
                Button {
                    Task {
                        await viewModel.evaluate(
                            sourceText: sourceText,
                            afmTranslation: afmTranslation,
                            mlxTranslation: mlxTranslation,
                            appleTranslation: appleTranslation,
                            targetLanguage: targetLanguage
                        )
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Compare")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(!canCompare)
            }
        }
    }
    
    private var notConfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("API Key Required")
                .font(.headline)
            
            Text("Set the OPENAI_API_KEY environment variable to enable LLM-as-a-Judge comparison.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var evaluatingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            if viewModel.currentRetryAttempt > 1 {
                Text("Retrying... (Attempt \(viewModel.currentRetryAttempt)/3)")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            } else {
                Text("Evaluating translations...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var readyToEvaluateView: some View {
        VStack(spacing: 8) {
            Image(systemName: canCompare ? "arrow.triangle.2.circlepath" : "hourglass")
                .font(.largeTitle)
                .foregroundColor(canCompare ? .purple : .secondary)
            
            Text(canCompare ? "Ready to Compare" : "Waiting for Translations")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(canCompare 
                 ? "Click 'Compare' to evaluate all three translations using GPT-5.1"
                 : "Complete at least 2 translations to enable comparison")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private func resultsView(judgement: TranslationJudgement) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Winner banner
            winnerBanner(judgement: judgement)
            
            // Score cards - now showing all three
            HStack(spacing: 12) {
                scoreCard(
                    title: "Apple FM",
                    icon: "apple.logo",
                    score: judgement.afmScore,
                    color: viewModel.afmScoreColor
                )
                
                scoreCard(
                    title: "MLX/Gemma",
                    icon: "brain",
                    score: judgement.mlxScore,
                    color: viewModel.mlxScoreColor
                )
                
                scoreCard(
                    title: "Apple Trans",
                    icon: "globe",
                    score: judgement.appleTranslationScore,
                    color: viewModel.appleTranslationScoreColor
                )
            }
            
            // Explanation
            VStack(alignment: .leading, spacing: 4) {
                Text("Analysis")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Text(judgement.explanation)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            // Key differences (expandable)
            DisclosureGroup("Key Differences", isExpanded: $viewModel.showDetailedResults) {
                Text(judgement.keyDifferences)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            
            // Clear button
            HStack {
                Spacer()
                Button {
                    viewModel.clear()
                } label: {
                    Text("Clear Results")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
    }
    
    private func winnerBanner(judgement: TranslationJudgement) -> some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundColor(.yellow)
            
            Text("Winner: \(viewModel.winnerDisplay)")
                .font(.subheadline.weight(.semibold))
            
            Spacer()
            
            Text("Overall: \(judgement.overallScore)/10")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(viewModel.winnerColor.opacity(0.2))
                .cornerRadius(8)
        }
        .padding()
        .background(viewModel.winnerColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func scoreCard(title: String, icon: String, score: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(.secondary)
            
            Text("\(score)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text("/ 10")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func errorView(error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        TranslationJudgeView(
            viewModel: TranslationJudgeViewModel(),
            sourceText: "Hello, welcome to our banking app.",
            afmTranslation: "Bonjour, bienvenue dans notre application bancaire.",
            mlxTranslation: "Bonjour, bienvenue à notre application de banque.",
            appleTranslation: "Bonjour, bienvenue sur notre application bancaire.",
            targetLanguage: .french,
            canCompare: true
        )
    }
    .padding()
}
