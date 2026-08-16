# Tranz

<p align="center">
  <img src="icons/AppIcon.png" alt="Tranz App Icon" width="128" height="128" />
</p>

<p align="center">
  <strong>Instant in-place text translation for any macOS application.</strong>
</p>

---

**Tranz** is a lightweight, native macOS menu bar utility that translates the active text input in **any** application—browsers, native apps, Electron apps, or text editors—and replaces it in-place with a single keyboard shortcut.

Powered by any OpenAI-compatible LLM endpoint (such as local models via [Ollama](https://ollama.com) or cloud providers), Tranz preserves your clipboard history and works seamlessly without disrupting your workflow.

---

## Features

* **Universal In-Place Translation**: Focus on any editable text field in any macOS app, press your shortcut, and translate text directly in-place.
* **Privacy-First and Self-Hostable**: Works out of the box with local AI endpoints (Ollama, LM Studio, vLLM) or remote providers (OpenAI, DeepSeek, Groq).
* **Keychain Encryption**: API keys are securely stored in the native macOS Keychain—never in plaintext files.
* **Non-Destructive Clipboard**: Your existing clipboard content is automatically preserved and restored before and after translation.
* **Customizable Global Hotkey**: Trigger translation anywhere with a rebindable shortcut (default: `Option+T` / `⌥T`).
* **Smart Language Detection**: Auto-detects the source language or allows fixed source-to-target language pairs.

---

## Quick Start

### 1. Build from Source

```bash
# Clone repository
git clone https://github.com/yourusername/tranz.git
cd tranz

# Compile release binary and assemble .app bundle
./scripts/build-app.sh

# Launch Tranz
open build/Tranz.app
```

### 2. First-Run Setup

1. **Accessibility Permissions**: When prompted, grant Tranz Accessibility permission under **System Settings → Privacy & Security → Accessibility**, then relaunch the app (required by macOS to simulate text selection and replacement).
2. **Configure AI Service**: Click the Tranz icon in your menu bar and select **Settings…**:
   * **Endpoint URL**: e.g., `http://localhost:11434/v1` (for Ollama) or `https://api.openai.com/v1`
   * **API Key**: Optional for local models; securely stored in Keychain for cloud services.
   * **Model**: e.g., `qwen2.5`, `llama3.1`, `gpt-4o-mini`, `gemini-2.5-flash`
   * **Target Language**: Choose your preferred destination language.

---

## Usage

1. Type or select text in any application (e.g., Slack, Notes, Safari, VS Code, Mail).
2. Press **`Option+T`** (`⌥T`).
3. The focused text is automatically translated in-place. If needed, standard **`Command+Z`** (`⌘Z` / Undo) reverts the translation immediately.

---

## Requirements

* **macOS 13.0 (Ventura)** or later
* **Xcode Command Line Tools** (`swift`, `codesign`)
* An OpenAI-compatible `/chat/completions` API endpoint (local or cloud)

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
