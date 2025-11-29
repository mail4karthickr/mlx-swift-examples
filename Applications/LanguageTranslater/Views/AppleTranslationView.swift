//
//  AppleTranslationView.swift
//  LanguageTranslater
//
//  A dedicated view for Apple Translation framework translation.
//  This uses Apple's built-in translation engine (different from Foundation Models).
//

import SwiftUI

#if canImport(Translation)
import Translation
#endif

/// A dedicated view for Apple Translation framework
struct AppleTranslationView: View {
    
    // MARK: - Properties
    
    /// The view model for Apple Translation
    @Bindable var viewModel: AppleTranslationViewModel
    
    /// The source text to translate (passed from parent)
    let sourceText: String
    
    /// Callback to copy text to clipboard
    var onCopy: ((String) -> Void)?
    
    /// Track translation start time
    @State private var translationStartTime: Date?
    
    /// Translated text result
    @State private var translatedText: String = ""
    
    /// Translation configuration
    #if canImport(Translation)
    @State private var configuration: TranslationSession.Configuration?
    #endif
    
    /// Whether translation is in progress
    @State private var isTranslating: Bool = false
    
    /// Error message
    @State private var errorMessage: String?
    
    /// Translation time
    @State private var translationTime: Double?
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            availabilityInfo
            translationOutput
            translateButton
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        #if canImport(Translation)
        .modifier(TranslationTaskModifier(
            configuration: $configuration,
            sourceText: sourceText,
            translatedText: $translatedText,
            isTranslating: $isTranslating,
            translationStartTime: $translationStartTime,
            translationTime: $translationTime,
            errorMessage: $errorMessage
        ))
        #endif
        // Sync local state back to view model
        .onChange(of: isTranslating) { _, newValue in
            viewModel.isTranslating = newValue
        }
        .onChange(of: translatedText) { _, newValue in
            if !newValue.isEmpty, let time = translationTime {
                viewModel.handleTranslationResponse(newValue, time: time)
            }
        }
    }
    
    // MARK: - Section Header
    
    private var sectionHeader: some View {
        HStack {
            Image(systemName: "translate")
                .foregroundColor(.blue)
            Text("Apple Translation")
                .font(.headline)
            
            Spacer()
        }
    }
    
    // MARK: - Availability Info
    
    private var availabilityInfo: some View {
        Group {
            if !viewModel.isAvailable {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(viewModel.availabilityMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Translation Output
    
    private var translationOutput: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(viewModel.selectedLanguage.fullDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Copy button
                if !translatedText.isEmpty {
                    Button {
                        onCopy?(translatedText)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Translation timing stats
            if let time = translationTime {
                HStack(spacing: 16) {
                    Label(String(format: "%.2fs", time), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)
            }
            
            // Output text area
            ScrollView {
                Text(translatedText.isEmpty ? "Translation will appear here..." : translatedText)
                    .foregroundColor(translatedText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 250)
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            
            // Error message
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Translate Button (Below text field)
    
    private var translateButton: some View {
        HStack {
            Spacer()
            
            if viewModel.isAvailable {
                Button {
                    triggerTranslation()
                } label: {
                    if isTranslating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(minWidth: 120)
                    } else {
                        Label("Translate", systemImage: "arrow.triangle.2.circlepath")
                            .frame(minWidth: 120)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(sourceText.isEmpty || isTranslating)
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Translation Trigger
    
    private func triggerTranslation() {
        #if canImport(Translation)
        translationStartTime = Date()
        isTranslating = true
        viewModel.isTranslating = true  // Sync with view model
        errorMessage = nil
        
        // Get target language locale
        let targetLocale = Locale.Language(identifier: viewModel.selectedLanguage.translationLocaleIdentifier)
        let sourceLocale = Locale.Language(identifier: "en")
        
        if configuration == nil {
            // First time - create configuration with specific languages
            configuration = TranslationSession.Configuration(
                source: sourceLocale,
                target: targetLocale
            )
        } else {
            // Update target language and invalidate to trigger new translation
            configuration?.target = targetLocale
            configuration?.invalidate()
        }
        #endif
    }
}

// MARK: - Translation Task Modifier

#if canImport(Translation)
@available(iOS 17.4, macOS 14.4, *)
struct TranslationTaskModifier: ViewModifier {
    @Binding var configuration: TranslationSession.Configuration?
    let sourceText: String
    @Binding var translatedText: String
    @Binding var isTranslating: Bool
    @Binding var translationStartTime: Date?
    @Binding var translationTime: Double?
    @Binding var errorMessage: String?
    
    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in
                do {
                    let response = try await session.translate(sourceText)
                    translatedText = response.targetText
                    
                    if let startTime = translationStartTime {
                        translationTime = Date().timeIntervalSince(startTime)
                    }
                } catch {
                    errorMessage = "Translation failed: \(error.localizedDescription)"
                }
                isTranslating = false
            }
    }
}

extension View {
    @ViewBuilder
    func applyTranslationTask(
        configuration: Binding<TranslationSession.Configuration?>,
        sourceText: String,
        translatedText: Binding<String>,
        isTranslating: Binding<Bool>,
        translationStartTime: Binding<Date?>,
        translationTime: Binding<Double?>,
        errorMessage: Binding<String?>
    ) -> some View {
        if #available(iOS 17.4, macOS 14.4, *) {
            self.modifier(TranslationTaskModifier(
                configuration: configuration,
                sourceText: sourceText,
                translatedText: translatedText,
                isTranslating: isTranslating,
                translationStartTime: translationStartTime,
                translationTime: translationTime,
                errorMessage: errorMessage
            ))
        } else {
            self
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    AppleTranslationView(
        viewModel: AppleTranslationViewModel(),
        sourceText: "Hello, how are you?"
    )
    .padding()
}

// MARK: - Preview

#Preview {
    AppleTranslationView(
        viewModel: AppleTranslationViewModel(),
        sourceText: "Hello, how are you?"
    )
    .padding()
}
