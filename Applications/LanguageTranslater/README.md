# Language Translator

A SwiftUI application that translates text from English to Russian, Chinese, Vietnamese, and French using MLX-powered Large Language Models from Hugging Face.

## Features

- **MLX-Powered Translation**: Uses Qwen2.5 1.5B model running locally on Apple Silicon
- **Multiple Target Languages**: Supports Russian, Chinese, Vietnamese, and French
- **Real-time Translation**: See tokens generated in real-time as translation progresses
- **Performance Stats**: View tokens per second performance metrics
- **Clean UI**: Modern SwiftUI interface with copy-to-clipboard support

## Setup Instructions

### Adding Dependencies in Xcode

Since this app uses MLX LLM models, you need to add the required package dependencies to the LanguageTranslater target:

1. Open `mlx-swift-examples.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the **LanguageTranslater** target
4. Go to **General** tab → **Frameworks, Libraries, and Embedded Content**
5. Click the **+** button and add:
   - `MLXLLM` (from mlx-swift-libs package)

Alternatively, in the **Build Phases** tab, add these to **Link Binary With Libraries**.

### Entitlements

The app requires the following entitlements (already configured in `LanguageTranslater.entitlements`):
- `com.apple.security.network.client` - For downloading models from Hugging Face

## Usage

1. Launch the app
2. Wait for the model to download (first launch only, ~3GB for Qwen2.5 1.5B)
3. Enter English text in the input field
4. Select target language (Russian, Chinese, Vietnamese, or French)
5. Click "Translate" button
6. View translation results with performance stats

## Architecture

```
LanguageTranslater/
├── ContentView.swift           # Main UI view
├── LanguageTranslaterApp.swift # App entry point
├── LanguageTranslater.entitlements
├── Models/
│   └── TargetLanguage.swift    # Target language enum
├── ViewModels/
│   └── TranslatorViewModel.swift # Translation logic and state
└── Assets.xcassets/
```

## Future Enhancements

This is Phase 1 (Hugging Face MLX models). Planned additions:
- **Phase 2**: Apple Foundation Models integration
- **Phase 3**: Apple Translation Framework integration
- **Comparison Mode**: Side-by-side comparison of all three translation methods

## Requirements

- macOS 14.0+
- Apple Silicon Mac (M1 or later)
- Xcode 15.0+
- ~4GB free disk space for model download
