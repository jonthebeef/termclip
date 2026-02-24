import Foundation

struct ClipFixConfig: Codable, Sendable {
    var notificationsEnabled: Bool
    var terminalBundleIDs: [String]

    static let defaultConfig = ClipFixConfig(
        notificationsEnabled: false,
        terminalBundleIDs: [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "dev.warp.Warp-Stable",
            "com.microsoft.VSCode",
            "net.kovidgoyal.kitty",
            "io.alacritty",
            "com.github.wez.wezterm",
            "co.zeit.hyper",
            "dev.zed.Zed",
            "com.todesktop.230313mzl4w4u92", // Cursor
        ]
    )

    static func load(from url: URL) throws -> ClipFixConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ClipFixConfig.self, from: data)
    }

    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}
