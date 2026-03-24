import Foundation

class WhisperService {
    /// URLSession with a hard cap on total request time (upload + server processing + download)
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30   // max idle time between packets
        config.timeoutIntervalForResource = 120 // max total time for entire request
        return URLSession(configuration: config)
    }()

    func transcribe(audioFileURL: URL) async throws -> String {
        // Retry once on transient failure
        do {
            return try await attemptTranscribe(audioFileURL: audioFileURL)
        } catch {
            if isTransient(error) {
                log("Whisper request failed (\(error.localizedDescription)), retrying once...")
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s backoff
                return try await attemptTranscribe(audioFileURL: audioFileURL)
            }
            throw error
        }
    }

    private func isTransient(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [.timedOut, .networkConnectionLost, .notConnectedToInternet,
                    .cannotConnectToHost, .cannotFindHost].contains(urlError.code)
        }
        if let whisperError = error as? WhisperError,
           case .apiError(let code, _) = whisperError, code >= 500 {
            return true // server errors are retryable
        }
        return false
    }

    private func attemptTranscribe(audioFileURL: URL) async throws -> String {
        guard let url = URL(string: "\(Config.openAIBaseURL)/audio/transcriptions") else {
            throw WhisperError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: audioFileURL)
        var body = Data()

        // model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(Config.whisperModel)\r\n".data(using: .utf8)!)

        // language hint — skips auto-detection for faster processing
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)

        // audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? "Unknown error"
            throw WhisperError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return result.text
    }

    struct WhisperResponse: Decodable {
        let text: String
    }

    enum WhisperError: LocalizedError {
        case invalidURL
        case invalidResponse
        case apiError(statusCode: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Whisper API URL"
            case .invalidResponse:
                return "Invalid response from Whisper API"
            case .apiError(let code, let message):
                return "Whisper API error (\(code)): \(message)"
            }
        }
    }
}
