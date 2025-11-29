//
//  TargetLanguage.swift
//  LanguageTranslater
//
//  Created by Karthick Ramasamy on 28/11/25.
//

import Foundation

/// Supported target languages for translation
enum TargetLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case chinese = "zh"
    case vietnamese = "vi"
    case french = "fr"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .russian:
            return "🇷🇺 RU"
        case .chinese:
            return "🇨🇳 ZH"
        case .vietnamese:
            return "🇻🇳 VI"
        case .french:
            return "🇫🇷 FR"
        }
    }
    
    var fullDisplayName: String {
        switch self {
        case .russian:
            return "🇷🇺 Russian"
        case .chinese:
            return "🇨🇳 Chinese"
        case .vietnamese:
            return "🇻🇳 Vietnamese"
        case .french:
            return "🇫🇷 French"
        }
    }
    
    var languageName: String {
        switch self {
        case .russian:
            return "Russian"
        case .chinese:
            return "Chinese"
        case .vietnamese:
            return "Vietnamese"
        case .french:
            return "French"
        }
    }
    
    var nativeName: String {
        switch self {
        case .russian:
            return "Русский"
        case .chinese:
            return "中文"
        case .vietnamese:
            return "Tiếng Việt"
        case .french:
            return "Français"
        }
    }
    
    /// Locale identifier for Apple Translation framework
    /// Some languages need specific variants (e.g., zh-Hans for Simplified Chinese)
    var translationLocaleIdentifier: String {
        switch self {
        case .russian:
            return "ru"
        case .chinese:
            return "zh-Hans" // Simplified Chinese
        case .vietnamese:
            return "vi"
        case .french:
            return "fr"
        }
    }
}
