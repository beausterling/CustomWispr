import Foundation

class AICleanupService {
    private let systemPrompt = """
    You are a light-touch text cleanup assistant for speech-to-text transcriptions.

    Rules:
    - Only remove pure filler sounds: uh, um, er, ah, hmm
    - KEEP words like "like", "right", "so", "well", "basically", "actually" — these are part of natural speech and often carry meaning
    - Fix obvious grammar mistakes and punctuation
    - Fix capitalization
    - Preserve the speaker's exact wording as much as possible
    - Preserve meaning, tone, and intent — do not rephrase or restructure sentences
    - Preserve technical terms, proper nouns, and jargon
    - Do NOT rewrite or paraphrase — only make minimal corrections
    - Do NOT add commentary or notes
    - Return ONLY the cleaned text, nothing else
    """

    func cleanup(rawText: String) async -> String {
        // Apply find/replace BEFORE GPT so Whisper misspellings (e.g. names) are
        // corrected before GPT tries to interpret them
        let replaced = SettingsManager.shared.applyReplacements(rawText)
        do {
            return try await callGPT(rawText: replaced)
        } catch {
            log("GPT cleanup failed: \(error.localizedDescription). Using replaced text.")
            return replaced
        }
    }

    private func callGPT(rawText: String) async throws -> String {
        guard let url = URL(string: "\(Config.openAIBaseURL)/chat/completions") else {
            throw CleanupError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(Config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": Config.gptModel,
            "temperature": 0.1,
            "max_tokens": 2048,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": rawText]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? "Unknown error"
            throw CleanupError.apiError(errorBody)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw CleanupError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum CleanupError: LocalizedError {
        case invalidURL
        case apiError(String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .apiError(let msg): return "GPT API error: \(msg)"
            case .parseError: return "Failed to parse GPT response"
            }
        }
    }
}
