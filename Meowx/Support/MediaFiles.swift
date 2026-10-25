import Foundation

enum MediaFiles {
    static let subtitles: Set<String> = ["srt", "vtt", "ass", "ssa", "sub", "idx"]
    private static let junk: Set<String> = [
        "txt", "nfo", "jpg", "jpeg", "png", "gif", "webp", "torrent", "url", "html", "htm", "pdf", "zip", "rar", "7z", "cue", "log", "md", "sfv", "ds_store"
    ]

    static func isSubtitle(_ url: URL) -> Bool {
        subtitles.contains(url.pathExtension.lowercased())
    }

    static func isM3U(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "m3u"
    }

    static func isJunk(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") { return true }
        return junk.contains(url.pathExtension.lowercased())
    }
}

enum TimeFormat {
    static func string(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}

enum SettingsStore {
    private static let key = "PlayerSettings"

    static func load() -> PlayerSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(PlayerSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    static func save(_ settings: PlayerSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum AppPaths {
    static var support: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Meowx", isDirectory: true)
    }
}
