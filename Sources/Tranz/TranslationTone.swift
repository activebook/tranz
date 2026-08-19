import Foundation

/// Defines stylistic personas for translation and monolingual text rewriting.
enum TranslationTone: String, CaseIterable, Identifiable, Codable {
    case `default`
    case professional
    case friendly
    case straightforward
    case imaginative
    case efficient
    case roasting
    case inspiring

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .professional:
            return "Professional & Rigorous"
        case .friendly:
            return "Amiable & Friendly"
        case .straightforward:
            return "Straightforward"
        case .imaginative:
            return "Imaginative"
        case .efficient:
            return "Efficient & Pragmatic"
        case .roasting:
            return "Sarcastic & Witty"
        case .inspiring:
            return "Inspiring & Guiding"
        }
    }

    var description: String {
        switch self {
        case .default:
            return "Natural and faithful translation without a specific stylistic bias."
        case .professional:
            return "Clear, accurate, and trustworthy with authoritative domain terminology."
        case .friendly:
            return "Warm, approachable, and encouraging conversational voice."
        case .straightforward:
            return "Concise, direct, no nonsense, hits straight to the point."
        case .imaginative:
            return "Highly creative, rich in metaphors, analogies, and evocative prose."
        case .efficient:
            return "Minimal words, maximum information density, action-oriented."
        case .roasting:
            return "Sharp, humorous roasting and playful banter, but never hurtful."
        case .inspiring:
            return "Guides thinking through questions, teaches skills and empowers reflection."
        }
    }

    var iconName: String {
        switch self {
        case .default:
            return "circle"
        case .professional:
            return "briefcase.fill"
        case .friendly:
            return "face.smiling.fill"
        case .straightforward:
            return "arrow.right.circle.fill"
        case .imaginative:
            return "sparkles"
        case .efficient:
            return "bolt.fill"
        case .roasting:
            return "flame.fill"
        case .inspiring:
            return "lightbulb.fill"
        }
    }

    /// The prompt directive injected into the LLM system prompt.
    var promptDirective: String? {
        switch self {
        case .default:
            return nil
        case .professional:
            return "Style: Professional & Rigorous. Ensure clear, accurate, and authoritative phrasing with precise terminology."
        case .friendly:
            return "Style: Amiable & Friendly. Use a warm, approachable, supportive, and encouraging voice."
        case .straightforward:
            return "Style: Straightforward & Concise. Eliminate fluff and redundant phrasing; deliver the core point directly."
        case .imaginative:
            return "Style: Imaginative & Creative. Use vivid imagery, expressive prose, and evocative metaphors where appropriate."
        case .efficient:
            return "Style: Efficient & Pragmatic. Maximize information density with the minimum necessary words."
        case .roasting:
            return "Style: Sarcastic & Witty. Apply sharp, playful roasting and humorous banter, while ensuring it remains harmless and entertaining."
        case .inspiring:
            return "Style: Inspiring & Guiding. Formulate an empowering, thought-provoking voice that guides reflection."
        }
    }
}
