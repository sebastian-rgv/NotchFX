import Foundation
import Testing
@testable import notchFXApp

struct CharacterProfileTests {
    @Test func legacySettingsKeepValuesAndYieldNoCharacters() throws {
        let legacy = #"{"displayMode":"mainScreen","surfaceStyle":"capsule","swipeDismissEnabled":false,"alertDuration":9,"islandWidth":380,"islandHeight":60}"#

        let decoded = try JSONDecoder().decode(
            NotchSettings.self,
            from: Data(legacy.utf8)
        )

        #expect(decoded.displayMode == .mainScreen)
        #expect(decoded.surfaceStyle == .capsule)
        #expect(decoded.swipeDismissEnabled == false)
        #expect(decoded.alertDuration == 9)
        #expect(decoded.characters.isEmpty)
    }

    @Test func decodesCharactersTolerantly() throws {
        let json = #"""
        {"characters":[
          {"name":"A","command":"echo a","style":"blinky"},
          {"name":"B"},
          {"name":"C","command":"echo c","style":"unknown"}
        ]}
        """#

        let decoded = try JSONDecoder().decode(
            NotchSettings.self,
            from: Data(json.utf8)
        )
        let sanitized = decoded.sanitized()

        #expect(sanitized.characters.map(\.name) == ["A", "C"])
        #expect(sanitized.characters.last?.style == .blinky)
    }

    @Test func roundtripPreservesCharacters() throws {
        var settings = NotchSettings.standard
        settings.characters = [
            CharacterProfile(
                name: "Despliegue",
                style: .clyde,
                command: "vercel deploy",
                workingDirectory: "/tmp"
            )
        ]

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(NotchSettings.self, from: data)

        #expect(decoded == settings)
    }

    @Test func sanitizeTrimsDropsAndLimits() {
        var settings = NotchSettings.standard
        settings.characters = [
            CharacterProfile(name: "  ", command: "  echo hola  "),
            CharacterProfile(name: "Sin comando", command: "   ")
        ]

        let sanitized = settings.sanitized()

        #expect(sanitized.characters.count == 1)
        #expect(sanitized.characters.first?.name == "Personaje 1")
        #expect(sanitized.characters.first?.command == "echo hola")

        settings.characters = (1...20).map {
            CharacterProfile(name: "P\($0)", command: "echo \($0)")
        }
        #expect(settings.sanitized().characters.count == 12)
    }

    @Test func sanitizeRegeneratesDuplicateIDs() {
        let duplicated = UUID()
        var settings = NotchSettings.standard
        settings.characters = [
            CharacterProfile(id: duplicated, name: "Uno", command: "echo 1"),
            CharacterProfile(id: duplicated, name: "Dos", command: "echo 2")
        ]

        let sanitized = settings.sanitized()
        #expect(sanitized.characters.count == 2)
        #expect(Set(sanitized.characters.map(\.id)).count == 2)
    }

    @Test func sanitizeClearsBlankWorkingDirectory() {
        var settings = NotchSettings.standard
        settings.characters = [
            CharacterProfile(
                name: "Uno",
                command: "echo 1",
                workingDirectory: "   "
            )
        ]

        #expect(settings.sanitized().characters.first?.workingDirectory == nil)
    }

    @Test func ansiStripperRemovesColourSequences() {
        let coloured = "\u{1B}[31mrojo\u{1B}[0m"
        #expect(ANSIStripper.strip(coloured) == "rojo")
        #expect(ANSIStripper.strip("sin color") == "sin color")
    }
}
