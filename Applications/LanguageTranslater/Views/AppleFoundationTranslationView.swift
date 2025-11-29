//
//  AppleFoundationTranslationView.swift
//  LanguageTranslater
//
//  A dedicated view for Apple Foundation Models translation.
//  This view is completely independent of the MLX/Hugging Face translation UI.
//

import SwiftUI

/// A dedicated view for Apple Foundation Models translation
struct AppleFoundationTranslationView: View {
    
    // MARK: - Properties
    
    /// The view model for Apple Foundation Models translation
    @Bindable var viewModel: AppleTranslatorViewModel
    
    /// The source text to translate (passed from parent)
    let sourceText: String
    
    /// Callback to copy text to clipboard
    var onCopy: ((String) -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            availabilityInfo
            translationOutput
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Section Header
    
    private var sectionHeader: some View {
        HStack {
            Image(systemName: "apple.intelligence")
                .foregroundColor(.purple)
            Text("Apple Foundation Models")
                .font(.headline)
            
            Spacer()
            
            // Status badge
            if viewModel.isAvailable {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Label("Unavailable", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Availability Info
    
    private var availabilityInfo: some View {
        HStack {
            if viewModel.isWarmingUp {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 4)
                Text(viewModel.availabilityMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if viewModel.isAvailable {
                Image(systemName: viewModel.isWarmedUp ? "bolt.fill" : "sparkles")
                    .foregroundColor(.purple)
                Text(viewModel.availabilityMessage)
                    .font(.subheadline)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text(viewModel.availabilityMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Translation Output
    
    private var translationOutput: some View {
        VStack(alignment: .leading, spacing: 4) {
            outputHeader
            
            // Translation timing stats
            if viewModel.timeToFirstToken != nil || viewModel.totalTranslationTime != nil {
                timingView
            }
            
            outputTextArea
            actionButtons
        }
    }
    
    private var outputHeader: some View {
        HStack {
            Text(viewModel.selectedLanguage.fullDisplayName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if !viewModel.translatedText.isEmpty {
                Button {
                    onCopy?(viewModel.translatedText)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
        }
    }
    
    private var timingView: some View {
        HStack(spacing: 16) {
            if let ttft = viewModel.timeToFirstToken {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundColor(.purple)
                    Text("First token: \(String(format: "%.2fs", ttft))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let total = viewModel.totalTranslationTime {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Total: \(String(format: "%.2fs", total))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var outputTextArea: some View {
        ScrollView {
            Text(viewModel.translatedText.isEmpty ? "Translation will appear here..." : viewModel.translatedText)
                .foregroundColor(viewModel.translatedText.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(8)
        }
        .frame(height: 250)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Translate button
            Button {
                viewModel.sourceText = sourceText
                Task {
                    await viewModel.translate()
                }
            } label: {
                HStack {
                    if viewModel.isTranslating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 4)
                        Text("Translating...")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Translate with Apple Intelligence")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(sourceText.isEmpty || viewModel.isTranslating || !viewModel.isAvailable)
            
            // Cancel button (shown when translating)
            if viewModel.isTranslating {
                Button {
                    viewModel.cancelTranslation()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            
            // Clear button (shown when there's output)
            if !viewModel.translatedText.isEmpty && !viewModel.isTranslating {
                Button {
                    viewModel.translatedText = ""
                    viewModel.timeToFirstToken = nil
                    viewModel.totalTranslationTime = nil
                } label: {
                    Image(systemName: "trash")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .help("Clear translation")
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - Preview

#Preview {
    AppleFoundationTranslationView(
        viewModel: AppleTranslatorViewModel(),
        sourceText: "Hello, how are you today?"
    ) { text in
        print("Copied: \(text)")
    }
    .padding()
}
