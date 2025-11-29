//
//  ContentView.swift
//  LanguageTranslater
//
//  Created by Karthick Ramasamy on 28/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = TranslatorViewModel()
    @State private var appleViewModel = AppleTranslatorViewModel()
    @State private var appleTranslationViewModel = AppleTranslationViewModel()
    @State private var judgeViewModel = TranslationJudgeViewModel()
    
    /// Check if at least two translations are available for comparison
    private var canCompare: Bool {
        // Count how many translations we have
        let hasMLX = !viewModel.translatedText.isEmpty
        let hasAFM = !appleViewModel.translatedText.isEmpty
        let hasAppleTranslation = !appleTranslationViewModel.translatedText.isEmpty
        
        // Need at least two translations to compare
        let translationCount = [hasMLX, hasAFM, hasAppleTranslation].filter { $0 }.count
        
        // Also ensure none are currently translating
        let notTranslating = !viewModel.isTranslating && 
                            !appleViewModel.isTranslating && 
                            !appleTranslationViewModel.isTranslating
        
        return translationCount >= 2 && notTranslating
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Target language selector (common for all models)
                    targetLanguageSelector
                    
                    // Source language and input (English)
                    sourceInputView
                    
                    Divider()
                    
                    // MARK: - Translation Results Section
                    
                    // 1. MLX Model Translation
                    MLXTranslationView(
                        viewModel: viewModel,
                        onCopy: copyToClipboard,
                        onOpenModelSettings: {
                            viewModel.isModelSettingsPresented = true
                        }
                    )
                    
                    // 2. Apple Foundation Models
                    AppleFoundationTranslationView(
                        viewModel: appleViewModel,
                        sourceText: viewModel.sourceText,
                        onCopy: copyToClipboard
                    )
                    
                    // 3. Apple Translation Framework
                    AppleTranslationView(
                        viewModel: appleTranslationViewModel,
                        sourceText: viewModel.sourceText,
                        onCopy: copyToClipboard
                    )
                    
                    Divider()
                    
                    // 4. LLM Judge - Compare translations (always visible, enabled when translations are ready)
                    TranslationJudgeView(
                        viewModel: judgeViewModel,
                        sourceText: viewModel.sourceText,
                        afmTranslation: appleViewModel.translatedText,
                        mlxTranslation: viewModel.translatedText,
                        appleTranslation: appleTranslationViewModel.translatedText,
                        targetLanguage: viewModel.selectedLanguage,
                        canCompare: canCompare
                    )
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Language Translator")
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $viewModel.isModelSettingsPresented) {
                ModelSettingsView(viewModel: viewModel)
            }
            .alert("Apple Foundation Model Error", isPresented: .constant(appleViewModel.errorMessage != nil)) {
                Button("OK") {
                    appleViewModel.errorMessage = nil
                }
            } message: {
                if let error = appleViewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .task {
            // Check downloaded models when view appears (runs on background thread)
            await viewModel.checkDownloadedModels()
            await appleViewModel.checkAvailability()
            appleTranslationViewModel.checkAvailability()
            
            // Warm up Apple Foundation Models in background for faster first translation
            // This is optional - remove if you don't want automatic warm-up
            await appleViewModel.warmUp()
        }
        .onChange(of: viewModel.selectedLanguage) { _, newValue in
            appleViewModel.selectedLanguage = newValue
            appleTranslationViewModel.selectedLanguage = newValue
            // Clear judge results when language changes
            judgeViewModel.clear()
        }
        .onChange(of: viewModel.sourceText) { _, _ in
            // Clear judge results when source text changes
            judgeViewModel.clear()
        }
    }
    
    // MARK: - Target Language Selector (Common for all models)
    private var targetLanguageSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translate to")
                .font(.headline)
                .foregroundColor(.primary)
            
            Picker("Target Language", selection: $viewModel.selectedLanguage) {
                ForEach(TargetLanguage.allCases) { language in
                    Text(language.displayName)
                        .tag(language)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Source Input View
    private var sourceInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🇺🇸 English")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    viewModel.clearInput()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(viewModel.sourceText.isEmpty ? 0 : 1)
            }
            
            TextEditor(text: $viewModel.sourceText)
                .frame(height: 250)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.sourceText.isEmpty {
                        Text("Enter text to translate...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
    
    // MARK: - Helper Functions
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - Model Settings View
struct ModelSettingsView: View {
    @Bindable var viewModel: TranslatorViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.availableMLXModels) { model in
                        ModelRowView(
                            model: model,
                            isSelected: viewModel.selectedMLXModel?.id == model.id,
                            onSelect: {
                                Task {
                                    await viewModel.selectModel(model)
                                }
                            },
                            onDownload: {
                                Task {
                                    await viewModel.downloadModel(model)
                                }
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteModel(model)
                                }
                            }
                        )
                    }
                } header: {
                    Text("Gemma 3n Models")
                } footer: {
                    Text("Models are downloaded from Hugging Face and run locally on your device using MLX.")
                }
            }
            .navigationTitle("Model Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // No need to check again - already checked on app launch
                print("📱 Model Settings View appeared")
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - Model Row View
struct ModelRowView: View {
    let model: MLXTranslationModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator (acts as checkbox for downloaded models)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .secondary)
                .font(.title2)
            
            // Model info
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)
                
                // Show "Downloaded" status when downloaded
                if model.isDownloaded {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Download/Delete button
            if model.isDownloading {
                VStack(spacing: 4) {
                    ProgressView(value: model.downloadProgress)
                        .frame(width: 80)
                    Text("\(Int(model.downloadProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if model.isDownloaded {
                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            } else {
                Button(action: onDownload) {
                    Text("Download")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if model.isDownloaded {
                onSelect()
            }
        }
    }
}

#Preview {
    ContentView()
}
