import Foundation

enum AdapterPayloadParser {
    static func parse(_ payload: [String: Any], now: Date) -> NowPlayingSnapshot? {
        guard let title = payload["title"] as? String, !title.isEmpty else {
            return nil
        }

        let artist = payload["artist"] as? String ?? ""
        let album = payload["album"] as? String
        let duration = payload["duration"] as? Double ?? 0
        let elapsed = payload["elapsedTime"] as? Double ?? 0

        let isPlaying = (payload["playing"] as? Bool) ?? false
        let rate = payload["playbackRate"] as? Double ?? (isPlaying ? 1 : 0)

        var timestamp = now
        if let timestampString = payload["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let parsed = formatter.date(from: timestampString) {
                timestamp = parsed
            }
        }

        let bundleID = payload["bundleIdentifier"] as? String ?? ""
        let source: NowPlayingSource
        switch bundleID {
        case "com.spotify.client":
            source = .spotify
        case "com.apple.Music":
            source = .appleMusic
        default:
            source = .mediaRemote
        }

        return NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsed: elapsed,
            rate: rate,
            timestamp: timestamp,
            isPlaying: isPlaying,
            source: source
        )
    }

    static func parse(streamLine: Data, now: Date) -> NowPlayingSnapshot? {
        guard
            let object = try? JSONSerialization.jsonObject(with: streamLine),
            let dictionary = object as? [String: Any],
            dictionary["type"] as? String == "data",
            let payload = dictionary["payload"] as? [String: Any]
        else {
            return nil
        }

        return parse(payload, now: now)
    }
}

final class MediaRemoteAdapterProvider {
    private let handler: (NowPlayingSnapshot?) -> Void
    private var streamProcess: Process?

    private let perlPath = "/usr/bin/perl"

    private var scriptPath: String? {
        Self.resourcePath("adapter/mediaremote-adapter.pl")
            ?? devFallbackPath.map { $0 + "/bin/mediaremote-adapter.pl" }
    }

    private var frameworkPath: String? {
        Self.resourcePath("adapter/MediaRemoteAdapter.framework")
            ?? devFallbackPath.map { $0 + "/build_out/MediaRemoteAdapter.framework" }
    }

    private var testClientPath: String? {
        Self.resourcePath("adapter/MediaRemoteAdapterTestClient")
            ?? devFallbackPath.map { $0 + "/build_out/MediaRemoteAdapterTestClient" }
    }

    private var devFallbackPath: String? {
        let candidate = "/tmp/mra-src"
        return FileManager.default.fileExists(atPath: candidate) ? candidate : nil
    }

    init(handler: @escaping (NowPlayingSnapshot?) -> Void) {
        self.handler = handler
    }

    static func resourcePath(_ relative: String) -> String? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let url = resources.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
    }

    func isAvailable() -> Bool {
        guard
            let scriptPath,
            let frameworkPath,
            FileManager.default.isExecutableFile(atPath: perlPath)
        else {
            return false
        }

        guard let testClientPath else {
            return runSync(arguments: [scriptPath, frameworkPath, "test"]) == 0
        }

        return runSync(arguments: [scriptPath, frameworkPath, testClientPath, "test"]) == 0
    }

    func start(onData: @escaping (NowPlayingSnapshot?) -> Void) {
        stop()

        guard
            let scriptPath,
            let frameworkPath,
            FileManager.default.isExecutableFile(atPath: perlPath)
        else {
            onData(nil)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: perlPath)
        process.arguments = [
            scriptPath,
            frameworkPath,
            "stream",
            "--no-diff",
            "--no-artwork"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async { onData(nil) }
            return
        }

        streamProcess = process

        DispatchQueue.global(qos: .utility).async { [weak process] in
            let fileHandle = pipe.fileHandleForReading
            var buffer = Data()

            while true {
                guard let process, process.isRunning else { break }
                let chunk = fileHandle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)

                while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let line = buffer.subdata(in: buffer.startIndex..<newlineIndex)
                    buffer.removeSubrange(buffer.startIndex...newlineIndex)

                    guard !line.isEmpty,
                          let snapshot = AdapterPayloadParser.parse(
                              streamLine: line,
                              now: Date()
                          )
                    else { continue }

                    DispatchQueue.main.async {
                        onData(snapshot)
                    }
                }
            }
        }
    }

    func stop() {
        guard let process = streamProcess, process.isRunning else { return }
        process.terminate()
        streamProcess = nil
    }

    func send(commandID: String) {
        runAdapterCommand(["send", commandID])
    }

    func seek(to seconds: Double) {
        runAdapterCommand(["seek", String(Int(max(0, seconds) * 1_000_000))])
    }

    private func runAdapterCommand(_ arguments: [String]) {
        guard
            let scriptPath,
            let frameworkPath
        else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: perlPath)
        process.arguments = [scriptPath, frameworkPath] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        DispatchQueue.global(qos: .utility).async {
            try? process.run()
            process.waitUntilExit()
        }
    }

    private func runSync(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: perlPath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
