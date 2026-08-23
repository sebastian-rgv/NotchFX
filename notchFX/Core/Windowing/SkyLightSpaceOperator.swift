import AppKit
import Darwin

enum SkyLightSpaceLevel: Int32, CaseIterable {
    case islandSurface = 2_147_483_647
}

final class SkyLightSpaceOperator {
    static let shared = SkyLightSpaceOperator()

    private typealias MainConnectionIDFunction = @convention(c) () -> Int32
    private typealias SpaceCreateFunction = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SpaceSetAbsoluteLevelFunction = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpacesFunction = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindowsAndRemoveFromSpacesFunction = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private let connection: Int32?
    private let islandSpace: Int32?
    private let addWindowsAndRemoveFromSpaces: AddWindowsAndRemoveFromSpacesFunction?

    private init() {
        let frameworkPath = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"

        guard
            let handle = dlopen(frameworkPath, RTLD_NOW),
            let mainConnectionIDSymbol = dlsym(handle, "SLSMainConnectionID"),
            let spaceCreateSymbol = dlsym(handle, "SLSSpaceCreate"),
            let spaceSetAbsoluteLevelSymbol = dlsym(handle, "SLSSpaceSetAbsoluteLevel"),
            let showSpacesSymbol = dlsym(handle, "SLSShowSpaces"),
            let addWindowsAndRemoveFromSpacesSymbol = dlsym(handle, "SLSSpaceAddWindowsAndRemoveFromSpaces")
        else {
            connection = nil
            islandSpace = nil
            addWindowsAndRemoveFromSpaces = nil
            return
        }

        let mainConnectionID = unsafeBitCast(mainConnectionIDSymbol, to: MainConnectionIDFunction.self)
        let spaceCreate = unsafeBitCast(spaceCreateSymbol, to: SpaceCreateFunction.self)
        let spaceSetAbsoluteLevel = unsafeBitCast(spaceSetAbsoluteLevelSymbol, to: SpaceSetAbsoluteLevelFunction.self)
        let showSpaces = unsafeBitCast(showSpacesSymbol, to: ShowSpacesFunction.self)
        let addWindowsAndRemoveFromSpaces = unsafeBitCast(addWindowsAndRemoveFromSpacesSymbol, to: AddWindowsAndRemoveFromSpacesFunction.self)

        let connection = mainConnectionID()
        let space = spaceCreate(connection, 1, 0)

        if space != 0 {
            _ = spaceSetAbsoluteLevel(connection, space, SkyLightSpaceLevel.islandSurface.rawValue)
            _ = showSpaces(connection, [space] as CFArray)
        }

        self.connection = connection
        self.islandSpace = space
        self.addWindowsAndRemoveFromSpaces = addWindowsAndRemoveFromSpaces
    }

    var isAvailable: Bool {
        connection != nil && islandSpace != 0 && addWindowsAndRemoveFromSpaces != nil
    }

    func delegateWindow(_ window: NSWindow) {
        guard
            let connection,
            let islandSpace,
            islandSpace != 0,
            let addWindowsAndRemoveFromSpaces
        else { return }

        _ = addWindowsAndRemoveFromSpaces(
            connection,
            islandSpace,
            [window.windowNumber] as CFArray,
            7
        )
    }
}
