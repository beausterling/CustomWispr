import Foundation

struct Replacement {
    var find: String
    var replace: String
}

class SettingsManager {
    static let shared = SettingsManager()

    private let settingsPath: String
    private var _replacements: [Replacement] = []

    var replacements: [Replacement] {
        get { _replacements }
        set {
            _replacements = newValue
            save()
        }
    }

    private init() {
        settingsPath = NSString("~/.custom-wispr-settings.json").expandingTildeInPath
        load()
    }

    func applyReplacements(_ text: String) -> String {
        var result = text
        for r in _replacements {
            guard !r.find.isEmpty else { continue }
            result = result.replacingOccurrences(of: r.find, with: r.replace, options: .caseInsensitive)
        }
        return result
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: settingsPath),
              let data = FileManager.default.contents(atPath: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["replacements"] as? [[String: String]] else {
            return
        }
        _replacements = arr.compactMap { dict in
            guard let find = dict["find"], let replace = dict["replace"] else { return nil }
            return Replacement(find: find, replace: replace)
        }
    }

    private func save() {
        let arr = _replacements.map { ["find": $0.find, "replace": $0.replace] }
        let json: [String: Any] = ["replacements": arr]
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            log("ERROR: Failed to serialize settings")
            return
        }
        FileManager.default.createFile(atPath: settingsPath, contents: data, attributes: [.posixPermissions: 0o600])
    }
}
