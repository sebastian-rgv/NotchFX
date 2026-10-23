import AppKit
import Carbon.HIToolbox

func nfxTrace(_ message: String) {
    guard ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" else { return }
    print("TRACE-" + message)
}

@main
final class AppMain {
    static func main() {
        setbuf(__stdoutp, nil)
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum MenuTag {
        static let displayAuto = 0
        static let displayNotched = 1
        static let displayMain = 2
        static let capsuleToggle = 10
        static let swipeToggle = 11
        static let charactersMenu = 12
    }

    private let stateModel = NotchStateModel()
    private lazy var engine = ActivityEngine(stateModel: stateModel)
    private lazy var timerController = LocalTimerController(engine: engine)
    private lazy var settingsModel = SettingsModel(
        store: SettingsStore(defaults: .standard)
    )
    private lazy var nowPlayingController = NowPlayingActivityController(
        engine: engine
    )
    private lazy var terminalController = TerminalController(engine: engine)
    private lazy var charactersController = CharacterSessionController(engine: engine)
    private lazy var cameraMonitor = CameraMonitor { [weak self] inUse in
        MainActor.assumeIsolated {
            self?.handleCamera(inUse: inUse)
        }
    }
    private lazy var panelController = NotchPanelController(
        stateModel: stateModel,
        engine: engine,
        settingsModel: settingsModel,
        nowPlaying: nowPlayingController,
        terminal: terminalController,
        characters: charactersController,
        onManageCharacters: { [weak self] in
            self?.settingsWindow.present(section: .characters)
        }
    )
    private lazy var settingsWindow = SettingsWindowController(
        settingsModel: settingsModel,
        characters: charactersController
    )

    private var batteryService: BatteryMonitorService?
    private var statusItem: NSStatusItem?
    private var outsideClickMonitor: Any?
    private var terminalHotKey: GlobalHotKey?
    private var charactersHotKey: GlobalHotKey?

    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("ZZTESTMARCADOR99 didload")
        if ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" {
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                let location = NSEvent.mouseLocation
                var tappedIsland = false

                if let self, self.panelController.isPointOverIsland(location) {
                    tappedIsland = true
                    DispatchQueue.main.async {
                        self.panelController.handleGlobalClick(at: location)
                    }
                }

                if ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" {
                    let line = "\(Date()) GLOBAL click \(location) isla=\(tappedIsland)"
                    if let handle = FileHandle(forWritingAtPath: "/tmp/nfx_events.log") {
                        handle.seekToEndOfFile()
                        handle.write(line.data(using: .utf8)!)
                        handle.closeFile()
                    } else {
                        try? line.write(toFile: "/tmp/nfx_events.log", atomically: true, encoding: .utf8)
                    }
                }
                _ = event
            }
        }

        let others = NSRunningApplication.runningApplications(
            withBundleIdentifier: "dev.notchfx.notchFX"
        ).filter { $0 != NSRunningApplication.current }

        for stale in others.dropFirst() {
            stale.terminate()
        }

        installStatusItem()
        installTerminalHotKey()
        installCharactersHotKey()
        startBatteryMonitoring()
        installOutsideClickMonitor()
        nowPlayingController.start()
        // CAMERA_TEST_OFF cameraMonitor.start()
        nfxTrace("DIDLOAD llamando a show()")
        panelController.show()
        nfxTrace("DIDLOAD show() completado")

    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlayingController.stop()
        charactersController.stopAll()
        batteryService?.stop()

        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        outsideClickMonitor = nil
    }

    // MARK: - Status item

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.inset.filled",
            accessibilityDescription: "NotchFX"
        )

        let menu = NSMenu()
        menu.delegate = self

        let settings = NSMenuItem(
            title: "Ajustes…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let terminal = menu.addItem(
            withTitle: "Terminal (fx.sh)",
            action: #selector(runFxScript),
            keyEquivalent: "t"
        )
        terminal.target = self
        terminal.keyEquivalentModifierMask = [.command, .option]

        let charactersItem = menu.addItem(
            withTitle: "Personajes",
            action: nil,
            keyEquivalent: ""
        )
        charactersItem.tag = MenuTag.charactersMenu
        charactersItem.submenu = NSMenu()

        menu.addItem(withTitle: "Temporizador demo (10 s)", action: #selector(startDemoTimer), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Alerta de prueba", action: #selector(emitTestAlert), keyEquivalent: "").target = self
        menu.addItem(.separator())

        let screenItem = menu.addItem(withTitle: "Pantalla", action: nil, keyEquivalent: "")
        let screenSubmenu = NSMenu()
        screenSubmenu.addItem(withTitle: "Automática", action: #selector(setDisplayMode(_:)), keyEquivalent: "").tag = MenuTag.displayAuto
        screenSubmenu.addItem(withTitle: "Con muesca", action: #selector(setDisplayMode(_:)), keyEquivalent: "").tag = MenuTag.displayNotched
        screenSubmenu.addItem(withTitle: "Principal", action: #selector(setDisplayMode(_:)), keyEquivalent: "").tag = MenuTag.displayMain
        for subitem in screenSubmenu.items {
            subitem.target = self
        }
        screenItem.submenu = screenSubmenu

        let capsule = menu.addItem(withTitle: "Cápsula flotante", action: #selector(toggleCapsule), keyEquivalent: "")
        capsule.target = self
        capsule.tag = MenuTag.capsuleToggle

        let swipe = menu.addItem(withTitle: "Deslizar para descartar", action: #selector(toggleSwipeDismiss), keyEquivalent: "")
        swipe.target = self
        swipe.tag = MenuTag.swipeToggle

        menu.addItem(.separator())
        menu.addItem(withTitle: "Salir de NotchFX", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildCharactersMenu(menu)
        refreshMenuState(menu)
    }

    // MARK: - Characters

    private func installCharactersHotKey() {
        charactersHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_P),
            modifiers: UInt32(cmdKey | optionKey)
        ) { [weak self] in
            MainActor.assumeIsolated {
                self?.openCharactersPanel()
            }
        }

        if charactersHotKey == nil {
            nfxTrace("Characters hotkey no se pudo registrar")
        }
    }

    @objc private func openCharactersPanel() {
        charactersController.openPanel(
            profiles: settingsModel.settings.characters
        )
    }

    @objc private func manageCharacters() {
        settingsWindow.present(section: .characters)
    }

    @objc private func runCharacter(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = UUID(uuidString: raw),
              let profile = settingsModel.settings.characters
                  .first(where: { $0.id == id }) else {
            return
        }
        charactersController.start(profile)
    }

    private func rebuildCharactersMenu(_ menu: NSMenu) {
        guard let item = menu.items.first(where: {
            $0.tag == MenuTag.charactersMenu
        }), let submenu = item.submenu else {
            return
        }

        submenu.removeAllItems()
        let profiles = settingsModel.settings.characters

        if profiles.isEmpty {
            let empty = NSMenuItem(
                title: "Sin personajes todavía",
                action: nil,
                keyEquivalent: ""
            )
            empty.isEnabled = false
            empty.tag = MenuTag.charactersMenu
            submenu.addItem(empty)
        } else {
            for profile in profiles {
                let item = NSMenuItem(
                    title: profile.name,
                    action: #selector(runCharacter(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = profile.id.uuidString
                item.tag = MenuTag.charactersMenu

                if charactersController.display.snapshots
                    .first(where: { $0.id == profile.id })?.state.isRunning == true {
                    item.state = .on
                    item.isEnabled = false
                }

                submenu.addItem(item)
            }
        }

        submenu.addItem(.separator())

        let open = NSMenuItem(
            title: "Abrir panel de personajes",
            action: #selector(openCharactersPanel),
            keyEquivalent: ""
        )
        open.target = self
        open.tag = MenuTag.charactersMenu
        submenu.addItem(open)

        let manage = NSMenuItem(
            title: "Gestionar personajes…",
            action: #selector(manageCharacters),
            keyEquivalent: ""
        )
        manage.target = self
        manage.tag = MenuTag.charactersMenu
        submenu.addItem(manage)
    }

    // MARK: - Terminal

    private func installTerminalHotKey() {
        terminalHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_T),
            modifiers: UInt32(cmdKey | optionKey)
        ) { [weak self] in
            MainActor.assumeIsolated {
                self?.terminalController.run()
            }
        }

        if terminalHotKey == nil {
            nfxTrace("Terminal hotkey no se pudo registrar")
        }
    }

    @objc private func runFxScript() {
        terminalController.run()
    }

    private func refreshMenuState(_ menu: NSMenu) {
        let current = settingsModel.settings

        for item in menu.items where item.submenu != nil {
            for subitem in item.submenu!.items {
                switch subitem.tag {
                case MenuTag.displayAuto:
                    subitem.state = current.displayMode == .auto ? .on : .off
                case MenuTag.displayNotched:
                    subitem.state = current.displayMode == .notchedScreen ? .on : .off
                case MenuTag.displayMain:
                    subitem.state = current.displayMode == .mainScreen ? .on : .off
                default:
                    break
                }
            }
        }

        for item in menu.items {
            switch item.tag {
            case MenuTag.capsuleToggle:
                item.state = current.surfaceStyle == .capsule ? .on : .off
            case MenuTag.swipeToggle:
                item.state = current.swipeDismissEnabled ? .on : .off
            default:
                break
            }
        }
    }

    @objc private func setDisplayMode(_ sender: NSMenuItem) {
        let mode: NotchSettings.DisplayMode
        switch sender.tag {
        case MenuTag.displayNotched:
            mode = .notchedScreen
        case MenuTag.displayMain:
            mode = .mainScreen
        default:
            mode = .auto
        }
        settingsModel.update { $0.displayMode = mode }
    }

    @objc private func toggleCapsule() {
        settingsModel.update { settings in
            settings.surfaceStyle = settings.surfaceStyle == .capsule ? .notch : .capsule
        }
    }

    @objc private func toggleSwipeDismiss() {
        settingsModel.update { $0.swipeDismissEnabled.toggle() }
    }

    // MARK: - Demo actions

    @objc private func openSettings() {
        settingsWindow.present()
    }

    @objc private func startDemoTimer() {
        timerController.start(duration: 10)
    }

    @objc private func emitTestAlert() {
        engine.present(
            testAlertActivity(),
            priority: .alert,
            ttl: settingsModel.settings.alertDuration
        )
    }

    private func testAlertActivity() -> NotchActivity {
        NotchActivity(
            id: ActivityID(rawValue: "test.alert.\(UUID().uuidString)"),
            kind: .battery,
            detail: .battery(percent: 42, isCharging: true)
        )
    }

    // MARK: - Battery

    private func startBatteryMonitoring() {
        let service = BatteryMonitorService { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleBatteryEvent(event)
            }
        }
        service.start()
        batteryService = service
    }

    private func handleCamera(inUse: Bool) {
        let id = ActivityID(rawValue: "camera.indicator")

        if inUse {
            engine.present(
                NotchActivity(
                    id: id,
                    kind: .camera,
                    detail: .info(symbol: "video.fill", label: "Cámara en uso")
                ),
                priority: .critical
            )
        } else {
            engine.finish(id)
        }
    }

    private func handleBatteryEvent(_ event: BatteryEvent) {
        engine.present(
            NotchActivity(
                id: ActivityID(rawValue: "battery.\(UUID().uuidString)"),
                kind: .battery,
                detail: event.detail
            ),
            priority: .alert,
            ttl: settingsModel.settings.alertDuration
        )
    }

    // MARK: - Outside click

    private func installOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panelController.handleOutsideClick(at: NSEvent.mouseLocation)
            }
        }
    }
}
