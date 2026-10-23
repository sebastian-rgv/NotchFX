import Foundation
import Testing
@testable import notchFXApp

@MainActor
struct CharacterSessionTests {
    private func makeController() -> CharacterSessionController {
        CharacterSessionController(
            engine: ActivityEngine(stateModel: NotchStateModel())
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 6,
        _ condition: () -> Bool
    ) async {
        let start = Date()
        while !condition(), Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
    }

    @Test func runsCommandAndReportsExitCode() async {
        let controller = makeController()
        let profile = CharacterProfile(
            name: "Falla",
            command: "printf 'hola\\n'; printf 'err\\n' >&2; exit 3"
        )

        controller.start(profile)
        await waitUntil { !controller.isRunning }

        #expect(controller.display.selectedLines.contains("hola"))
        #expect(controller.display.selectedLines.contains("err"))
        #expect(controller.display.snapshots.first?.state == .failed(exitCode: 3))
    }

    @Test func runsTwoCharactersConcurrentlyWithIsolatedLogs() async {
        let controller = makeController()
        let slow = CharacterProfile(
            name: "Lento",
            command: "printf 'A-1\\n'; sleep 0.6; printf 'A-2\\n'"
        )
        let fast = CharacterProfile(
            name: "Rápido",
            command: "printf 'B-1\\n'; sleep 0.1; printf 'B-2\\n'"
        )

        controller.openPanel(profiles: [slow, fast])
        controller.start(slow)
        controller.start(fast)

        #expect(controller.display.snapshots.filter { $0.state.isRunning }.count == 2)

        await waitUntil { !controller.isRunning }
        try? await Task.sleep(nanoseconds: 100_000_000)

        controller.select(slow.id)
        #expect(controller.display.selectedLines.contains("A-1"))
        #expect(controller.display.selectedLines.contains("A-2"))
        #expect(!controller.display.selectedLines.contains("B-1"))

        controller.select(fast.id)
        #expect(controller.display.selectedLines.contains("B-1"))
        #expect(controller.display.selectedLines.contains("B-2"))
        #expect(!controller.display.selectedLines.contains("A-1"))
    }

    @Test func stopMarksSessionStopped() async {
        let controller = makeController()
        let profile = CharacterProfile(name: "Largo", command: "sleep 10")

        controller.start(profile)
        try? await Task.sleep(nanoseconds: 150_000_000)
        #expect(controller.isRunning)

        controller.stop(profile.id)
        await waitUntil { !controller.isRunning }

        #expect(controller.display.snapshots.first?.state == .stopped)
    }

    @Test func respectsWorkingDirectory() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let controller = makeController()
        let profile = CharacterProfile(
            name: "PWD",
            command: "pwd",
            workingDirectory: directory.path
        )

        controller.start(profile)
        await waitUntil { !controller.isRunning }

        let printed = controller.display.selectedLines.last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let expected = directory.resolvingSymlinksInPath().path
        let actual = URL(fileURLWithPath: printed).resolvingSymlinksInPath().path

        #expect(actual == expected)
    }

    @Test func pathIncludesLocalBin() async {
        let controller = makeController()
        let profile = CharacterProfile(
            name: "PATH",
            command: "printf '%s\\n' \"$PATH\""
        )

        controller.start(profile)
        await waitUntil { !controller.isRunning }

        let line = controller.display.selectedLines.first ?? ""
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(line.contains("\(home)/.local/bin"))
    }

    @Test func stripsAnsiFromOutput() async {
        let controller = makeController()
        let profile = CharacterProfile(
            name: "Color",
            command: "printf '\\033[31mrojo\\033[0m\\n'"
        )

        controller.start(profile)
        await waitUntil { !controller.isRunning }

        #expect(controller.display.selectedLines.contains("rojo"))
    }

    @Test func invalidDirectoryFallsBackToHomeWithWarning() async {
        let controller = makeController()
        let profile = CharacterProfile(
            name: "Sin dir",
            command: "printf 'ok\\n'",
            workingDirectory: "/nonexistent/notchfx-directory"
        )

        controller.start(profile)
        await waitUntil { !controller.isRunning }

        #expect(
            controller.display.selectedLines.contains {
                $0.contains("Directorio no encontrado")
            }
        )
    }
}
