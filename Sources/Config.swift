import Foundation

enum Config {
    static let whisperModel = "whisper-1"
    static let gptModel = "gpt-4o-mini"
    static let openAIBaseURL = "https://api.openai.com/v1"

    static var apiKey: String {
        // Try ~/.custom-wispr.env first
        if let key = readKeyFromEnvFile() {
            return key
        }
        // Fall back to environment variable
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            return key
        }
        fatalError("No OpenAI API key found. Create ~/.custom-wispr.env with OPENAI_API_KEY=your-key-here or set OPENAI_API_KEY env var.")
    }

    private static func readKeyFromEnvFile() -> String? {
        let path = NSString("~/.custom-wispr.env").expandingTildeInPath
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        // Warn if env file is readable by group or others
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: path),
           let posix = attrs[.posixPermissions] as? Int {
            if posix & 0o077 != 0 {
                fputs("[WARNING] ~/.custom-wispr.env is readable by other users. Run: chmod 600 ~/.custom-wispr.env\n", stderr)
            }
        }

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("OPENAI_API_KEY=") {
                let value = String(trimmed.dropFirst("OPENAI_API_KEY=".count))
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }
}
