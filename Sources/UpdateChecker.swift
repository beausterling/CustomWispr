import Cocoa

class UpdateChecker {
    private static let repo = "beausterling/CustomWispr"
    private static let apiURL = "https://api.github.com/repos/\(repo)/releases/latest"

    /// Check for updates in the background after app launch
    static func checkForUpdates() {
        guard let url = URL(string: apiURL) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                log("Update check failed: \(error?.localizedDescription ?? "unknown error")")
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String else {
                log("Update check: couldn't parse response")
                return
            }

            // Strip leading "v" from tag if present (e.g. "v1.2" -> "1.2")
            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"

            log("Update check: current=\(currentVersion), latest=\(latestVersion)")

            guard isVersion(latestVersion, newerThan: currentVersion) else {
                log("App is up to date")
                return
            }

            // Get release notes (body) if available
            let releaseNotes = json["body"] as? String

            // Get DMG download URL from assets if available
            let dmgURL = findDMGAssetURL(in: json)

            DispatchQueue.main.async {
                showUpdateAlert(
                    currentVersion: currentVersion,
                    newVersion: latestVersion,
                    releasePageURL: htmlURL,
                    dmgDownloadURL: dmgURL,
                    releaseNotes: releaseNotes
                )
            }
        }.resume()
    }

    /// Compare semantic version strings (supports major.minor.patch)
    private static func isVersion(_ new: String, newerThan current: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newParts.count, currentParts.count) {
            let n = i < newParts.count ? newParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if n > c { return true }
            if n < c { return false }
        }
        return false
    }

    /// Find the first .dmg asset download URL from the release
    private static func findDMGAssetURL(in json: [String: Any]) -> String? {
        guard let assets = json["assets"] as? [[String: Any]] else { return nil }

        // Prefer Intel DMG for Intel users, Apple Silicon for ARM, or universal
        for asset in assets {
            guard let name = asset["name"] as? String,
                  name.hasSuffix(".dmg"),
                  let downloadURL = asset["browser_download_url"] as? String else { continue }

            #if arch(x86_64)
            if name.lowercased().contains("intel") || name.lowercased().contains("x86") {
                return downloadURL
            }
            #elseif arch(arm64)
            if name.lowercased().contains("apple") || name.lowercased().contains("arm") {
                return downloadURL
            }
            #endif
        }

        // Fallback: return the first DMG found (universal or unspecified)
        for asset in assets {
            if let name = asset["name"] as? String, name.hasSuffix(".dmg"),
               let downloadURL = asset["browser_download_url"] as? String {
                return downloadURL
            }
        }

        return nil
    }

    /// Quit the app after a short delay so the browser has time to start the download
    private static func quitAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            log("Quitting for update — drag the new app to Applications and relaunch")
            NSApp.terminate(nil)
        }
    }

    private static func showUpdateAlert(
        currentVersion: String,
        newVersion: String,
        releasePageURL: String,
        dmgDownloadURL: String?,
        releaseNotes: String?
    ) {
        // Bring app to front for the alert
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "CustomWispr v\(newVersion) is available (you have v\(currentVersion))."

        if let notes = releaseNotes, !notes.isEmpty {
            // Truncate long release notes
            let truncated = notes.count > 300 ? String(notes.prefix(300)) + "..." : notes
            alert.informativeText += "\n\n\(truncated)"
        }

        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage

        if dmgDownloadURL != nil {
            alert.addButton(withTitle: "Download Update")
        }
        alert.addButton(withTitle: "View Release")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if dmgDownloadURL != nil {
            // Buttons: Download (1000), View Release (1001), Later (1002)
            if response == .alertFirstButtonReturn, let urlStr = dmgDownloadURL,
               let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
                quitAfterDelay()
            } else if response == .alertSecondButtonReturn, let url = URL(string: releasePageURL) {
                NSWorkspace.shared.open(url)
                quitAfterDelay()
            }
        } else {
            // Buttons: View Release (1000), Later (1001)
            if response == .alertFirstButtonReturn, let url = URL(string: releasePageURL) {
                NSWorkspace.shared.open(url)
                quitAfterDelay()
            }
        }
    }
}
