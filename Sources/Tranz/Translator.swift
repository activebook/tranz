import Foundation

/// Configuration for a single translation request (mirrors the locked §3.3 contract).
struct TranslatorConfig {
    var baseURL: String      // e.g. "http://localhost:11434/v1" (already includes the /v1 segment)
    var apiKey: String?      // optional for many self-hosted servers
    var model: String
    var targetLanguage: String  // human-readable name, e.g. "English"
    var sourceLanguage: String  // "auto-detect" or a language name
    var preserveRawOutput: Bool = false
}

enum TranslatorError: LocalizedError {
    case invalidURL
    case emptyResponse
    case responseTruncated
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid endpoint URL."
        case .emptyResponse:
            return "The translation returned empty content."
        case .responseTruncated:
            return "Translation cut off: token limit reached."
        case .httpStatus(let code):
            return "The server returned HTTP \(code)."
        }
    }
}

/// Calls a self-hosted OpenAI-compatible `/chat/completions` endpoint.
///
/// `stream: false` (replace once, no flicker) and `temperature: 0` (deterministic)
/// are both hardcoded per the locked spec.
final class Translator {
    func translate(
        text: String,
        config: TranslatorConfig,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = base.hasSuffix("/") ? base + "chat/completions" : base + "/chat/completions"
        guard let url = URL(string: endpoint) else {
            completion(.failure(TranslatorError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = config.apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": config.model,
            "temperature": 0,
            "max_tokens": 4096,
            "stream": false,
            "messages": [
                ["role": "system", "content": Self.systemPrompt(targetLanguage: config.targetLanguage)],
                ["role": "user", "content": Self.userPrompt(config: config, text: text)]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                completion(.failure(TranslatorError.httpStatus(http.statusCode)))
                return
            }
            guard let data else {
                completion(.failure(TranslatorError.emptyResponse))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                let choice = decoded.choices.first
                let isTruncated = choice?.finish_reason == "length"
                let rawContent = choice?.message.content ?? ""
                let finalContent = config.preserveRawOutput
                    ? rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    : Self.sanitizeOutput(rawContent)

                if isTruncated && finalContent.isEmpty {
                    completion(.failure(TranslatorError.responseTruncated))
                    return
                }

                guard !finalContent.isEmpty else {
                    completion(.failure(TranslatorError.emptyResponse))
                    return
                }

                if isTruncated {
                    completion(.failure(TranslatorError.responseTruncated))
                    return
                }

                completion(.success(finalContent))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Output Sanitization

    /// Filters internal reasoning tags (e.g. `<think>...</think>`, `<thought>...</thought>`, and escaped variants),
    /// stripping chain-of-thought metadata and normalizing whitespace to yield strictly the translated text.
    static func sanitizeOutput(_ raw: String) -> String {
        // 1. Remove standard XML-like <think>...</think> and <thought>...</thought> blocks (case-insensitive, dotAll)
        let standardPattern = #"(?is)<think\b[^>]*>.*?</think>|<thought\b[^>]*>.*?</thought>"#
        var cleaned = raw.replacingOccurrences(of: standardPattern, with: "", options: .regularExpression)

        // 2. Remove escaped variants: \<think\>...\</think\> or &lt;think&gt;...&lt;/think&gt;
        let escapedPattern = #"(?is)\\<think\b[^>]*\\>.*?\\</think\\>|&lt;think\b[^&]*&gt;.*?&lt;/think&gt;"#
        cleaned = cleaned.replacingOccurrences(of: escapedPattern, with: "", options: .regularExpression)

        // 3. Strip unclosed leading <think> block if generation terminated abruptly before closing tag
        if let unclosedRegex = try? NSRegularExpression(pattern: #"^(?is)\s*(?:<think\b[^>]*>|\\<think\b[^>]*\\>|&lt;think\b[^&]*&gt;)(?!.*(?:</think>|\\</think\\>|&lt;/think&gt;)).*$"#),
           unclosedRegex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) != nil {
            cleaned = ""
        }

        // 4. Strip extraneous whitespace and newlines between reasoning blocks and output
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompts (locked §3.4)

    static func systemPrompt(targetLanguage: String) -> String {
        """
        You are a professional translator and a native speaker of \(targetLanguage).
        Translate the user's text into \(targetLanguage) faithfully and naturally.
        Preserve tone, formatting, line breaks, and any code or identifiers.
        Output ONLY the translated text — no explanations, no quotes, no markdown fences.
        """
    }

    static func userPrompt(config: TranslatorConfig, text: String) -> String {
        """
        Source language: \(config.sourceLanguage)
        Translate the above into \(config.targetLanguage).
        Text:
        \(text)
        """
    }
}

struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
        let finish_reason: String?
    }
    let choices: [Choice]
}
