import Combine
import Darwin
import Foundation

@MainActor
final class CharacterSessionController: ObservableObject {
    static let activityID = ActivityID(rawValue: "characters.sessions")
    static let maxLines = 500
    static let maxLineLength = 2000

    @Published private(set) var display: CharactersDisplay = .empty

    private let engine: ActivityEngine
    private var sessions: [UUID: Session] = [:]
    private var order: [UUID] = []
    private var selectedID: UUID?
    private var pendingPublish: DispatchWorkItem?

    private let publishInterval: TimeInterval = 0.05

    init(engine: ActivityEngine) {
        self.engine = engine
    }

    var isRunning: Bool {
        sessions.values.contains { $0.state.isRunning }
    }

    // MARK: - Public API

    /// Shows the roster even when nothing is running. Existing sessions keep
    /// their logs and state.
    func openPanel(profiles: [CharacterProfile]) {
        syncRoster(profiles)

        if selectedID == nil || !order.contains(selectedID ?? UUID()) {
            selectedID = profiles.first?.id
        }

        publishDisplay()
        if engine.isShowing(Self.activityID) {
            engine.update(makeActivity())
        } else {
            engine.focus(makeActivity(), priority: .alert)
        }
        engine.expand()
    }

    func start(_ profile: CharacterProfile) {
        var roster = order.compactMap { sessions[$0]?.profile }
        if let index = roster.firstIndex(where: { $0.id == profile.id }) {
            roster[index] = profile
        } else {
            roster.append(profile)
        }
        syncRoster(roster)

        guard let session = sessions[profile.id] else { return }
        guard !session.state.isRunning else { return }

        session.profile = profile
        session.lines = []
        session.generation = UUID()
        session.state = .running(startedAt: Date())
        selectedID = profile.id

        publishDisplay(focusIfHidden: true)
        launch(session)
    }

    func stop(_ id: UUID) {
        guard let session = sessions[id], session.state.isRunning else { return }

        session.state = .stopped
        session.process?.terminate()

        let process = session.process
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if let process, process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }

        publishDisplay()
    }

    func stopAll() {
        for id in order {
            stop(id)
        }
    }

    func select(_ id: UUID?) {
        selectedID = id
        publishDisplay()
    }

    /// Drops sessions whose profile no longer exists without opening or
    /// expanding the notch.
    func sync(profiles: [CharacterProfile]) {
        syncRoster(profiles)
        if let selectedID, !order.contains(selectedID) {
            self.selectedID = order.first
        }
        publishDisplay()
    }

    func dismiss() {
        stopAll()
        engine.finish(Self.activityID)
        sessions.removeAll()
        order.removeAll()
        selectedID = nil
        display = .empty
    }

    // MARK: - Roster

    private func syncRoster(_ profiles: [CharacterProfile]) {
        let incoming = Set(profiles.map(\.id))

        for id in order where !incoming.contains(id) {
            if let session = sessions.removeValue(forKey: id) {
                session.state = .stopped
                if session.process?.isRunning == true {
                    session.process?.terminate()
                }
            }
        }

        order = profiles.map(\.id)

        for profile in profiles {
            if let session = sessions[profile.id] {
                session.profile = profile
            } else {
                sessions[profile.id] = Session(profile: profile)
            }
        }

        if let selectedID, !incoming.contains(selectedID) {
            self.selectedID = profiles.first?.id
        }
    }

    // MARK: - Process

    private func launch(_ session: Session) {
        let profile = session.profile
        var warnings: [String] = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", profile.command]
        process.currentDirectoryURL = resolvedDirectory(
            for: profile,
            home: FileManager.default.homeDirectoryForCurrentUser,
            warnings: &warnings
        )
        process.environment = Self.environment()
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        session.process = process
        session.pipe = pipe

        if !warnings.isEmpty {
            session.lines.append(contentsOf: warnings)
            schedulePublish()
        }

        do {
            try process.run()
        } catch {
            session.state = .failed(exitCode: -1)
            session.lines.append("No se pudo ejecutar: \(error.localizedDescription)")
            publishDisplay()
            return
        }

        let generation = session.generation
        let handle = pipe.fileHandleForReading

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var buffer = TerminalLineBuffer()

            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }

                let lines = buffer.append(chunk)
                guard !lines.isEmpty else { continue }

                DispatchQueue.main.async {
                    self?.append(lines, to: session, generation: generation)
                }
            }

            if let remainder = buffer.flush(), !remainder.isEmpty {
                DispatchQueue.main.async {
                    self?.append([remainder], to: session, generation: generation)
                }
            }

            process.waitUntilExit()
            let status = process.terminationStatus

            DispatchQueue.main.async {
                self?.finish(session, generation: generation, status: status)
            }
        }
    }

    private func append(_ newLines: [String], to session: Session, generation: UUID) {
        guard sessions[session.profile.id] === session,
              session.generation == generation else {
            return
        }

        for line in newLines {
            var text = ANSIStripper.strip(line)
                .replacingOccurrences(of: "\r", with: "")
            if text.count > Self.maxLineLength {
                text = String(text.prefix(Self.maxLineLength))
            }
            session.lines.append(text)
        }

        if session.lines.count > Self.maxLines {
            session.lines.removeFirst(session.lines.count - Self.maxLines)
        }

        schedulePublish()
    }

    private func finish(_ session: Session, generation: UUID, status: Int32) {
        guard sessions[session.profile.id] === session,
              session.generation == generation else {
            return
        }

        session.process = nil
        session.pipe = nil

        if session.state != .stopped {
            session.state = status == 0 ? .succeeded : .failed(exitCode: status)
        }

        publishDisplay()
    }

    private func resolvedDirectory(
        for profile: CharacterProfile,
        home: URL,
        warnings: inout [String]
    ) -> URL {
        guard let raw = profile.workingDirectory?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return home
        }

        let expanded = (raw as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return URL(fileURLWithPath: expanded, isDirectory: true)
        }

        warnings.append("Directorio no encontrado: \(raw). Uso \(home.path).")
        return home
    }

    static func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let preferred = [
            "\(home)/.local/bin",
            "\(home)/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin"
        ]

        let current = environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []

        var seen = Set<String>()
        environment["PATH"] = (preferred + current)
            .filter { seen.insert($0).inserted }
            .joined(separator: ":")

        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        return environment
    }

    // MARK: - Publishing

    private func schedulePublish() {
        guard pendingPublish == nil else { return }

        let work = DispatchWorkItem { [weak self] in
            self?.pendingPublish = nil
            self?.publishDisplay()
        }
        pendingPublish = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + publishInterval,
            execute: work
        )
    }

    private func publishDisplay(focusIfHidden: Bool = false) {
        let snapshots = order.compactMap { id -> CharacterSnapshot? in
            guard let session = sessions[id] else { return nil }
            return CharacterSnapshot(
                id: id,
                name: session.profile.name,
                style: session.profile.style,
                state: session.state
            )
        }

        let currentSelection = selectedID ?? order.first
        let selectedSession = currentSelection.flatMap { sessions[$0] }

        display = CharactersDisplay(
            snapshots: snapshots,
            selectedID: currentSelection,
            selectedName: selectedSession?.profile.name,
            selectedLines: selectedSession?.lines ?? []
        )

        let activity = makeActivity()

        if focusIfHidden {
            if engine.isShowing(Self.activityID) {
                engine.update(activity)
            } else {
                engine.focus(activity, priority: .alert)
            }
        } else {
            engine.update(activity)
        }
    }

    private func makeActivity() -> NotchActivity {
        NotchActivity(
            id: Self.activityID,
            kind: .characters,
            detail: .characters(display)
        )
    }
}

private extension CharacterSessionController {
    /// Mutated only on the main actor; the unchecked conformance covers the
    /// capture in the background pipe-reading closures.
    final class Session: @unchecked Sendable {
        var profile: CharacterProfile
        var state: CharacterRunState = .idle
        var lines: [String] = []
        var process: Process?
        var pipe: Pipe?
        var generation = UUID()

        init(profile: CharacterProfile) {
            self.profile = profile
        }
    }
}
