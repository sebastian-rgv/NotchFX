import Combine
import Foundation

@MainActor
final class TerminalController: ObservableObject {
    static let activityID = ActivityID(rawValue: "terminal.session")
    static let scriptName = "fx.sh"

    @Published private(set) var display: TerminalDisplay?

    private let engine: ActivityEngine
    private let maxLines = 300

    private var process: Process?
    private var outputPipe: Pipe?
    private var readHandle: FileHandle?

    init(engine: ActivityEngine) {
        self.engine = engine
    }

    var isRunning: Bool { process?.isRunning ?? false }

    func run() {
        guard !isRunning else { return }

        guard let scriptPath = Self.resolveScriptPath() else {
            publish(
                TerminalDisplay(
                    scriptName: Self.scriptName,
                    lines: ["No se encontró \(Self.scriptName)."],
                    isRunning: false,
                    exitCode: nil
                )
            )
            return
        }

        publish(
            TerminalDisplay(
                scriptName: Self.scriptName,
                lines: [],
                isRunning: true,
                exitCode: nil
            ),
            forceDisplay: true
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptPath]
        process.currentDirectoryURL = URL(
            fileURLWithPath: (scriptPath as NSString).deletingLastPathComponent
        )

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice

        self.process = process
        self.outputPipe = pipe

        do {
            try process.run()
        } catch {
            appendLines(["Error al ejecutar: \(error.localizedDescription)"])
            finish(exitCode: -1)
            return
        }

        readHandle = pipe.fileHandleForReading
        pump(pipe.fileHandleForReading, process: process)
    }

    func dismiss() {
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        outputPipe = nil
        readHandle = nil
        engine.finish(Self.activityID)
        display = nil
    }

    // MARK: - Output streaming

    private func pump(_ handle: FileHandle, process: Process) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var buffer = TerminalLineBuffer()

            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }

                let lines = buffer.append(chunk)
                guard !lines.isEmpty else { continue }

                DispatchQueue.main.async {
                    self?.appendLines(lines)
                }
            }

            if let remainder = buffer.flush(), !remainder.isEmpty {
                DispatchQueue.main.async {
                    self?.appendLines([remainder])
                }
            }

            process.waitUntilExit()
            let status = process.terminationStatus

            DispatchQueue.main.async {
                self?.finish(exitCode: status)
            }
        }
    }

    private func appendLines(_ newLines: [String]) {
        guard let current = display else { return }

        var lines = current.lines + newLines
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }

        publish(
            TerminalDisplay(
                scriptName: current.scriptName,
                lines: lines,
                isRunning: current.isRunning,
                exitCode: current.exitCode
            )
        )
    }

    private func finish(exitCode: Int32) {
        process = nil
        outputPipe = nil
        readHandle = nil

        guard let current = display else { return }
        publish(
            TerminalDisplay(
                scriptName: current.scriptName,
                lines: current.lines,
                isRunning: false,
                exitCode: exitCode
            )
        )
    }

    private func publish(_ display: TerminalDisplay, forceDisplay: Bool = false) {
        self.display = display

        let activity = NotchActivity(
            id: Self.activityID,
            kind: .terminal,
            detail: .terminal(display)
        )

        if forceDisplay {
            engine.focus(activity, priority: .alert)
        } else {
            engine.present(activity, priority: .alert)
        }
    }

    // MARK: - Script resolution

    static func resolveScriptPath(fileManager: FileManager = .default) -> String? {
        if let override = ProcessInfo.processInfo.environment["NFX_FX_SCRIPT"],
           !override.isEmpty {
            return fileManager.fileExists(atPath: override) ? override : nil
        }

        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent(scriptName).path,
           fileManager.fileExists(atPath: bundled) {
            return bundled
        }

        // Development fallback: walk up from this source file to the repo root
        // and use Scripts/fx.sh.
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = directory
                .appendingPathComponent("Scripts")
                .appendingPathComponent(scriptName).path
            if fileManager.fileExists(atPath: candidate) {
                return candidate
            }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
        }

        return nil
    }
}
