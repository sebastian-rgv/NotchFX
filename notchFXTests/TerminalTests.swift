import Foundation
import Testing
@testable import notchFXApp

struct TerminalLineBufferTests {
    @Test func splitsCompleteLinesAndHoldsPartial() {
        var buffer = TerminalLineBuffer()
        let lines = buffer.append(Data("uno\ndos\ntres".utf8))
        #expect(lines == ["uno", "dos"])
        #expect(buffer.flush() == "tres")
    }

    @Test func stripsTrailingCarriageReturn() {
        var buffer = TerminalLineBuffer()
        let lines = buffer.append(Data("a\r\nb\r\n".utf8))
        #expect(lines == ["a", "b"])
        #expect(buffer.flush() == nil)
    }

    @Test func joinsChunkSplitAcrossBoundary() {
        var buffer = TerminalLineBuffer()
        #expect(buffer.append(Data("par".utf8)).isEmpty)
        #expect(buffer.append(Data("te\n".utf8)) == ["parte"])
    }

    @Test func flushReturnsNilWhenEmpty() {
        var buffer = TerminalLineBuffer()
        #expect(buffer.flush() == nil)
    }

    @Test func preservesEmptyLines() {
        var buffer = TerminalLineBuffer()
        let lines = buffer.append(Data("a\n\nb\n".utf8))
        #expect(lines == ["a", "", "b"])
    }
}

@MainActor
struct TerminalControllerTests {
    @Test func runsScriptAndStreamsOutput() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let script = directory.appendingPathComponent("fx.sh")
        try "echo hola\necho mundo >&2\nexit 3\n".write(to: script, atomically: true, encoding: .utf8)

        setenv("NFX_FX_SCRIPT", script.path, 1)
        defer { unsetenv("NFX_FX_SCRIPT") }

        let controller = TerminalController(engine: ActivityEngine(stateModel: NotchStateModel()))
        controller.run()

        var waited = 0.0
        while controller.isRunning, waited < 5 {
            try await Task.sleep(nanoseconds: 50_000_000)
            waited += 0.05
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let lines = controller.display?.lines ?? []
        #expect(lines.contains("hola"))
        #expect(lines.contains("mundo"))
        #expect(controller.display?.isRunning == false)
        #expect(controller.display?.exitCode == 3)
    }

    @Test func missingScriptReportsFailureWithoutRunning() async {
        setenv("NFX_FX_SCRIPT", "/nonexistent/fx.sh", 1)
        defer { unsetenv("NFX_FX_SCRIPT") }

        let controller = TerminalController(engine: ActivityEngine(stateModel: NotchStateModel()))
        controller.run()

        #expect(controller.isRunning == false)
        #expect(controller.display?.isRunning == false)
        #expect(controller.display?.lines.first?.contains("No se encontró") == true)
    }
}

struct TerminalDisplayTests {
    @Test func statusTextReflectsState() {
        #expect(
            TerminalDisplay(scriptName: "fx.sh", lines: [], isRunning: true, exitCode: nil)
                .statusText == "corriendo…"
        )
        #expect(
            TerminalDisplay(scriptName: "fx.sh", lines: [], isRunning: false, exitCode: 0)
                .statusText == "listo"
        )
        #expect(
            TerminalDisplay(scriptName: "fx.sh", lines: [], isRunning: false, exitCode: 2)
                .statusText == "error (2)"
        )
    }
}
