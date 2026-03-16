import Foundation

/// A very small wrapper around OpenRouter's Chat Completions API.
///
/// See: https://openrouter.ai/docs/quickstart
///
struct OpenRouterChatAPI {
    static let shared = OpenRouterChatAPI()

    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(apiKey: String? = nil,
         model: String = "nvidia/nemotron-nano-12b-v2-vl:free",
         session: URLSession = .shared) {
        self.apiKey = apiKey ?? Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String ?? ""
        self.model = model
        self.session = session
    }

    enum APIError: Error {
        case missingApiKey
        case invalidURL
        case invalidResponse
        case apiError(message: String)
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct RequestBody: Codable {
        let model: String
        let messages: [Message]
        var stream: Bool = false
    }

    struct Response: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let role: String
                let content: String
            }
            let message: Message
        }

        let id: String?
        let object: String?
        let created: Int?
        let model: String?
        let choices: [Choice]
        let error: ErrorResponse?

        struct ErrorResponse: Codable {
            let message: String?
            let type: String?
            let code: String?
        }
    }

    func sendMessage(_ message: String, systemPrompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw APIError.missingApiKey
        }

        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw APIError.invalidURL
        }

        var messages: [Message] = []
        if let systemPrompt {
            messages.append(.init(role: "system", content: systemPrompt))
        }
        messages.append(.init(role: "user", content: message))

        let body = RequestBody(model: model, messages: messages)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              200...299 ~= http.statusCode else {
            let payload = String(data: data, encoding: .utf8) ?? "<empty>"
            throw APIError.apiError(message: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1): \(payload)")
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        if let err = decoded.error, let msg = err.message {
            throw APIError.apiError(message: msg)
        }

        guard let firstChoice = decoded.choices.first else {
            throw APIError.invalidResponse
        }

        return firstChoice.message.content
    }
}
