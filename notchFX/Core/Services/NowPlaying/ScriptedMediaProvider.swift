import AppKit
import Foundation

@MainActor
final class ScriptedMediaProvider {
    private var pollTimer: Timer?
    private let handler: (NowPlayingSnapshot?) -> Void
    private(set) var lastSnapshot: NowPlayingSnapshot?

    private struct Target {
        let bundleID: String
        let appName: String
        let source: NowPlayingSource
    }

    private static let targets: [Target] = [
        Target(bundleID: "com.apple.Music", appName: "Music", source: .appleMusic),
        Target(bundleID: "com.spotify.client", appName: "Spotify", source: .spotify)
    ]

    init(handler: @escaping (NowPlayingSnapshot?) -> Void) {
        self.handler = handler
    }

    func start() {
        try? "started".write(toFile: "/tmp/nfx_debug_start", atomically: true, encoding: .utf8)
        guard pollTimer == nil else { return }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func send(_ command: NowPlayingCommand) {
        guard let target = runningTarget() else { return }
        let verb: String

        switch command {
        case .togglePlayPause:
            verb = "playpause"
        case .play:
            verb = "play"
        case .pause:
            verb = "pause"
        case .nextTrack:
            verb = target.appName == "Spotify" ? "next track" : "next track"
        case .previousTrack:
            verb = target.appName == "Spotify" ? "previous track" : "previous track"
        }

        _ = runOSA("tell application id \"\(target.bundleID)\" to \(verb)")
    }

    func seek(to seconds: Double) {
        guard let target = runningTarget() else { return }
        _ = runOSA(
            """
            tell application id "\(target.bundleID)"
                set player position to \(Int(seconds))
            end tell
            """
        )
    }

    func openSourceApp() {
        guard let target = runningTarget() ?? lastRunningTarget() else { return }
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/Applications/\(target.appName).app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    private func runningTarget() -> Target? {
        Self.targets.first { target in
            !NSRunningApplication.runningApplications(
                withBundleIdentifier: target.bundleID
            ).isEmpty
        }
    }

    private func lastRunningTarget() -> Target? {
        guard let source = lastSnapshot?.source else { return nil }
        return Self.targets.first { $0.source == source }
    }

    private func poll() {
        try? Date().description.write(toFile: "/tmp/nfx_debug_poll", atomically: true, encoding: .utf8)

        for target in Self.targets where isBundleRunning(target.bundleID) {
            try? target.bundleID.write(
                toFile: "/tmp/nfx_debug_target",
                atomically: true,
                encoding: .utf8
            )

            if let output = query(target: target) {
                try? output.write(
                    toFile: "/tmp/nfx_debug_query",
                    atomically: true,
                    encoding: .utf8
                )
                if let snapshot = Self.parseResponse(output, source: target.source, now: Date()) {
                    lastSnapshot = snapshot
                    handler(snapshot)
                    return
                }
            }
        }

        guard let lastSnapshot else { return }
        if lastSnapshot.isPlaying {
            let paused = NowPlayingSnapshot(
                title: lastSnapshot.title,
                artist: lastSnapshot.artist,
                album: lastSnapshot.album,
                duration: lastSnapshot.duration,
                elapsed: lastSnapshot.elapsed,
                rate: 0,
                timestamp: Date(),
                isPlaying: false,
                source: lastSnapshot.source
            )
            self.lastSnapshot = paused
            handler(paused)
        }
    }

    private func query(target: Target) -> String? {
        runOSA(
            """
            tell application id "\(target.bundleID)"
                if player state is stopped then return ""
                set trackInfo to current track
                return ((name of trackInfo) & "|" & (artist of trackInfo) & "|" & \
                    ((duration of trackInfo) as string) & "|" & \
                    ((player position) as string) & "|" & ((player state) as string))
            end tell
            """
        )
    }

    nonisolated static func parseResponse(
        _ output: String,
        source: NowPlayingSource,
        now: Date
    ) -> NowPlayingSnapshot? {
        let parts = output.components(separatedBy: "|")
        guard parts.count >= 5 else { return nil }

        let title = parts[0].trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }

        let rawState = parts[4].lowercased()
        let isPlaying = rawState.contains("playing")

        let rawDuration = Double(parts[2]) ?? 0
        let duration = source == .spotify ? rawDuration / 1000 : rawDuration

        return NowPlayingSnapshot(
            title: title,
            artist: parts[1],
            album: nil,
            duration: duration,
            elapsed: Double(parts[3]) ?? 0,
            rate: isPlaying ? 1 : 0,
            timestamp: now,
            isPlaying: isPlaying,
            source: source
        )
    }

    private func isBundleRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    private func runOSA(_ source: String) -> String? {
        try? source.write(
            toFile: "/tmp/nfx_debug_script",
            atomically: true,
            encoding: .utf8
        )
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            try? error.description.write(
                toFile: "/tmp/nfx_debug_error",
                atomically: true,
                encoding: .utf8
            )
            return nil
        }
        return result.stringValue
    }
}
