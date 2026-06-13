import AppKit

/// Checks GitHub Releases for a newer version and, on the user's confirm,
/// downloads the zip, swaps the running .app in place, and relaunches.
///
/// The app is self-signed (not notarized), so a freshly downloaded build
/// carries a quarantine flag that would trip Gatekeeper. We strip it after
/// download — a legitimate self-update of our own app (the same pattern
/// Homebrew casks use), not a security bypass.
@MainActor
public enum Updater {
    private static let repo = "DevooKim/my-alttab"
    private static let latestAPI = "https://api.github.com/repos/DevooKim/my-alttab/releases/latest"

    /// Current bundle version, or nil when running unbundled (`swift run`).
    private static var currentVersion: SemanticVersion? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            .flatMap(SemanticVersion.init)
    }

    /// `silent` suppresses the "you're up to date" / error alerts (used for
    /// the automatic check at launch); the explicit menu item shows them.
    public static func checkForUpdates(silent: Bool) {
        Task { await runCheck(silent: silent) }
    }

    private static var periodicTimer: Timer?

    /// Checks once now (silently) and then every 24h while the app runs.
    /// The launch check is unconditional; the recurring one keeps
    /// always-on users current without a restart.
    public static func startAutomaticChecks() {
        checkForUpdates(silent: true)
        periodicTimer?.invalidate()
        let interval: TimeInterval = 24 * 60 * 60
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in checkForUpdates(silent: true) }
        }
        timer.tolerance = 60 * 60 // an hour of slack; this isn't time-critical
        RunLoop.main.add(timer, forMode: .common)
        periodicTimer = timer
    }

    private static func runCheck(silent: Bool) async {
        guard let current = currentVersion else { return } // unbundled: skip
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }

        let release: Release
        do {
            release = try await fetchLatest()
        } catch {
            if !silent { showInfo(title: L("update.checkFailed.title"), text: "\(error.localizedDescription)") }
            return
        }

        guard let remote = SemanticVersion(release.tagName), remote > current else {
            if !silent {
                showInfo(title: L("update.upToDate.title"), text: String(format: L("update.upToDate.text"), current.description))
            }
            return
        }
        guard let asset = release.zipAsset else {
            if !silent { showInfo(title: L("update.notFound.title"), text: L("update.notFound.text")) }
            return
        }

        let proceed = confirmUpdate(from: current, to: remote, notes: release.body)
        guard proceed else { return }
        await downloadAndInstall(url: asset, version: remote)
    }

    // MARK: GitHub API

    private struct Release {
        let tagName: String
        let body: String
        let zipAsset: URL?
    }

    private static func fetchLatest() async throws -> Release {
        var request = URLRequest(url: URL(string: latestAPI)!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub rejects API requests without a User-Agent.
        request.setValue("MyAltTab-Updater", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            throw UpdateError.badResponse
        }
        let body = json["body"] as? String ?? ""
        let assets = json["assets"] as? [[String: Any]] ?? []
        let zip = assets.compactMap { $0["browser_download_url"] as? String }
            .first { $0.hasSuffix(".zip") }
            .flatMap(URL.init(string:))
        return Release(tagName: tag, body: body, zipAsset: zip)
    }

    // MARK: Install

    private static func downloadAndInstall(url: URL, version: SemanticVersion) async {
        do {
            let (tempZip, _) = try await URLSession.shared.download(from: url)
            let fm = FileManager.default
            let workDir = fm.temporaryDirectory.appendingPathComponent("MyAltTabUpdate-\(version.description)")
            try? fm.removeItem(at: workDir)
            try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

            // Unzip with ditto (preserves the signature).
            try run("/usr/bin/ditto", ["-x", "-k", tempZip.path, workDir.path])

            guard let newApp = try fm.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "app" }) else {
                throw UpdateError.noAppInZip
            }

            // Strip quarantine so the swapped-in build opens without a
            // Gatekeeper re-prompt (we trust our own release). Best-effort.
            _ = try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

            // Replace the running bundle in place.
            let installed = Bundle.main.bundleURL
            let backup = installed.appendingPathExtension("old")
            try? fm.removeItem(at: backup)
            try fm.moveItem(at: installed, to: backup)
            do {
                try fm.moveItem(at: newApp, to: installed)
            } catch {
                try? fm.moveItem(at: backup, to: installed) // roll back
                throw error
            }
            try? fm.removeItem(at: backup)

            relaunch(bundleURL: installed)
        } catch {
            showInfo(title: L("update.failed.title"), text: String(format: L("update.failed.text"), error.localizedDescription))
            openReleasesPage()
        }
    }

    private static func relaunch(bundleURL: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    @discardableResult
    private static func run(_ launchPath: String, _ args: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.commandFailed(launchPath) }
        return process.terminationStatus
    }

    // MARK: UI

    private static func confirmUpdate(from: SemanticVersion, to: SemanticVersion, notes: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(format: L("update.available.title"), to.description)
        let plain = plainText(fromMarkdown: notes)
        let trimmed = plain.split(separator: "\n", omittingEmptySubsequences: false).prefix(12).joined(separator: "\n")
        alert.informativeText = String(format: L("update.available.body"), from.description, to.description, trimmed)
        alert.addButton(withTitle: L("update.install"))
        alert.addButton(withTitle: L("common.later"))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// GitHub release bodies are Markdown; NSAlert shows plain text only, so
    /// the raw markup (##, -, **, `) leaks through. Convert the common syntax
    /// to readable plain text line-by-line.
    static func plainText(fromMarkdown markdown: String) -> String {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        return lines.map { rawLine -> String in
            var line = rawLine.trimmingCharacters(in: .whitespaces)

            // Headings: "## Title" -> "Title"
            while line.hasPrefix("#") { line.removeFirst() }
            line = line.trimmingCharacters(in: .whitespaces)

            // List markers: "- item" / "* item" / "+ item" -> "• item"
            for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
                line = "• " + line.dropFirst(marker.count)
                break
            }

            // Inline emphasis/code: **bold** __bold__ *italic* _italic_ `code`
            for token in ["**", "__", "*", "_", "`"] {
                line = line.replacingOccurrences(of: token, with: "")
            }

            // Links: [text](url) -> text
            line = stripLinks(line)
            return line
        }.joined(separator: "\n")
    }

    private static func stripLinks(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\([^)]+\)"#) else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: "$1")
    }

    private static func showInfo(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func openReleasesPage() {
        NSWorkspace.shared.open(URL(string: "https://github.com/\(repo)/releases/latest")!)
    }

    private enum UpdateError: LocalizedError {
        case badResponse, noAppInZip, commandFailed(String)
        var errorDescription: String? {
            switch self {
            case .badResponse: return L("update.error.badResponse")
            case .noAppInZip: return L("update.error.noAppInZip")
            case .commandFailed(let p): return String(format: L("update.error.commandFailed"), p)
            }
        }
    }
}
