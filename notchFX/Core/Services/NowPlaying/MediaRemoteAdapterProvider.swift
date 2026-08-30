import AppKit
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
    private var artworkProcess: Process?

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

    private static func trace(_ message: String) {
        guard ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" else { return }
        let line = "\(Date()) \(message)\n"
        if let handle = FileHandle(forWritingAtPath: "/tmp/nfx_debug.log") {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.write(toFile: "/tmp/nfx_debug.log", atomically: true, encoding: .utf8)
        }
    }

    static func resourcePath(_ relative: String) -> String? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let url = resources.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
    }

    func isAvailable() -> Bool {
        let pathsOk = scriptPath != nil && frameworkPath != nil
            && FileManager.default.isExecutableFile(atPath: perlPath)
        Self.trace("isAvailable pathsOk=\(pathsOk) script=\(scriptPath ?? "nil") framework=\(frameworkPath ?? "nil")")

        guard pathsOk, let scriptPath, let frameworkPath else { return false }

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
            Self.trace("stream ERROR al lanzar: \(error)")
            DispatchQueue.main.async { onData(nil) }
            return
        }

        streamProcess = process
        Self.trace("stream proceso lanzado pid=\(process.processIdentifier)")

        DispatchQueue.global(qos: .utility).async { [weak self, weak process] in
            let fileHandle = pipe.fileHandleForReading
            var buffer = Data()
            var lineCount = 0

            Self.trace("stream lector iniciado")

            while true {
                guard let process, process.isRunning else { break }
                let chunk = fileHandle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)

                while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let line = buffer.subdata(in: buffer.startIndex..<newlineIndex)
                    buffer.removeSubrange(buffer.startIndex...newlineIndex)

                    lineCount += 1
                    if lineCount <= 3 {
                        Self.trace("stream línea \(lineCount): \(line.prefix(120))")
                    }

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

            Self.trace("stream lector terminado (líneas: \(lineCount))")
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

    func fetchArtwork(completion: @escaping (NSImage?) -> Void) {
        cancelArtworkFetch()

        guard
            let scriptPath,
            let frameworkPath,
            FileManager.default.isExecutableFile(atPath: perlPath)
        else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: perlPath)
        process.arguments = [scriptPath, frameworkPath, "get"]
        process.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe

        artworkProcess = process

        process.terminationHandler = { [weak self] _ in
            guard let self else { return }
            if self.artworkProcess === process {
                self.artworkProcess = nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let base64 = object["artworkData"] as? String,
                let imageData = Data(base64Encoded: base64),
                let image = NSImage(data: imageData)
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            DispatchQueue.main.async { completion(image) }
        }

        do {
            try process.run()
        } catch {
            artworkProcess = nil
            DispatchQueue.main.async { completion(nil) }
        }
    }

    func cancelArtworkFetch() {
        guard let process = artworkProcess, process.isRunning else {
            artworkProcess = nil
            return
        }
        process.terminate()
        artworkProcess = nil
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
