//
//  MLXTranslationView.swift
//  LanguageTranslater
//
//  A dedicated view for MLX/Hugging Face (Gemma) translation.
//  This view is completely independent of Apple Foundation Models translation UI.
//

import SwiftUI

/// A dedicated view for MLX/Hugging Face translation
struct MLXTranslationView: View {
    
    // MARK: - Properties
    
    /// The view model for MLX translation
    @Bindable var viewModel: TranslatorViewModel
    
    /// Callback to copy text to clipboard
    var onCopy: ((String) -> Void)?
    
    /// Callback to open model settings
    var onOpenModelSettings: (() -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            selectedModelInfo
            translationOutput
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Section Header
    
    private var sectionHeader: some View {
        HStack {
            Image(systemName: "cpu")
                .foregroundColor(.blue)
            Text("MLX Model (Hugging Face)")
                .font(.headline)
            
            Spacer()
            
            Button {
                onOpenModelSettings?()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Model Settings")
        }
    }
    
    // MARK: - Selected Model Info
    
    private var selectedModelInfo: some View {
        HStack {
            // Show loading indicator when model is being loaded
            if viewModel.isLoadingModel {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 4)
                Text(viewModel.modelInfo ?? "Loading model...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if let model = viewModel.selectedMLXModel, model.isDownloaded {
                // Only show model info if it's downloaded
                Label {
                    Text(model.displayName)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            } else {
                // Show "No model exists" if no downloaded model is available
                Text("No model exists")
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
            if viewModel.timeToFirstToken != nil || viewModel.totalTranslationTime != nil || viewModel.translationStats != nil {
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
                        .foregroundColor(.blue)
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
            
            if let stats = viewModel.translationStats {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(stats)
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
                        Image(systemName: "cpu")
                        Text("Translate with MLX")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(viewModel.sourceText.isEmpty || viewModel.isTranslating || viewModel.selectedMLXModel == nil || !(viewModel.selectedMLXModel?.isDownloaded ?? false))
            
            // Cancel button (shown when translating)
            if viewModel.isTranslating {
                Button {
                    Task {
                        await viewModel.cancelTranslation()
                    }
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
                    viewModel.translationStats = nil
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
    MLXTranslationView(
        viewModel: TranslatorViewModel()
    ) { text in
        print("Copied: \(text)")
    } onOpenModelSettings: {
        print("Open settings")
    }
    .padding()
}
