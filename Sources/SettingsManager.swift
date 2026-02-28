import Foundation

class SettingsManager {
    static let shared = SettingsManager()

    private let settingsPath: String
    private var _customInstructions: String = ""

    var customInstructions: String {
        get { _customInstructions }
        set {
            _customInstructions = newValue
            save()
        }
    }

    private init() {
        settingsPath = NSString("~/.custom-wispr-settings.json").expandingTildeInPath
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: settingsPath),
              let data = FileManager.default.contents(atPath: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let instructions = json["customInstructions"] as? String else {
            return
        }
        _customInstructions = instructions
    }

    private func save() {
        let json: [String: Any] = ["customInstructions": _customInstructions]
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            log("ERROR: Failed to serialize settings")
            return
        }
        FileManager.default.createFile(atPath: settingsPath, contents: data, attributes: [.posixPermissions: 0o600])
    }
}
