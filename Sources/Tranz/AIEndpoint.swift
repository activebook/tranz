import Foundation

/// Represents a distinct AI service configuration profile.
struct AIEndpoint: Identifiable, Codable, Hashable, Equatable {
    var id: UUID
    var name: String
    var baseURL: String
    var model: String

    init(id: UUID = UUID(), name: String, baseURL: String, model: String) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.model = model
    }

    // MARK: - Factory Presets

    static var ollamaPreset: AIEndpoint {
        AIEndpoint(
            name: "Ollama (Local)",
            baseURL: "http://localhost:11434/v1",
            model: "qwen2.5:7b"
        )
    }

    static var openAIPreset: AIEndpoint {
        AIEndpoint(
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4o-mini"
        )
    }

    static var deepSeekPreset: AIEndpoint {
        AIEndpoint(
            name: "DeepSeek",
            baseURL: "https://api.deepseek.com/v1",
            model: "deepseek-chat"
        )
    }

    static var groqPreset: AIEndpoint {
        AIEndpoint(
            name: "Groq",
            baseURL: "https://api.groq.com/openai/v1",
            model: "llama-3.3-70b-versatile"
        )
    }

    static var customPreset: AIEndpoint {
        AIEndpoint(
            name: "Custom Service",
            baseURL: "http://localhost:8000/v1",
            model: "model-identifier"
        )
    }

    static var defaultPresets: [AIEndpoint] {
        [ollamaPreset, openAIPreset, deepSeekPreset]
    }
}
