import Foundation

/// Represents a distinct AI service configuration profile.
struct AIEndpoint: Identifiable, Codable, Hashable, Equatable {
    var id: UUID
    var baseURL: String
    var model: String

    init(id: UUID = UUID(), baseURL: String = "http://localhost:11434/v1", model: String = "qwen2.5:7b") {
        self.id = id
        self.baseURL = baseURL
        self.model = model
    }

    /// Automatically formats a clean, concise service identifier from the domain and model name.
    /// Examples: `localhost:gemini`, `groq:qwen2.6`, `openai:gpt5.5-nano`, `deepseek:deepseek-chat`
    var displayName: String {
        let domain: String
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespaces)

        if let url = URL(string: trimmedURL.contains("://") ? trimmedURL : "http://\(trimmedURL)"),
           let host = url.host?.lowercased() {
            if host == "localhost" || host == "127.0.0.1" || host == "0.0.0.0" {
                domain = "localhost"
            } else {
                let parts = host.split(separator: ".")
                if parts.count >= 2 {
                    // e.g. "api.groq.com" -> "groq", "api.openai.com" -> "openai", "api.deepseek.com" -> "deepseek"
                    domain = String(parts[parts.count - 2])
                } else if let first = parts.first {
                    domain = String(first)
                } else {
                    domain = "custom"
                }
            }
        } else {
            domain = "custom"
        }

        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        return trimmedModel.isEmpty ? domain : "\(domain):\(trimmedModel)"
    }

    static var defaultEndpoint: AIEndpoint {
        AIEndpoint(baseURL: "http://localhost:11434/v1", model: "qwen2.5:7b")
    }
}
