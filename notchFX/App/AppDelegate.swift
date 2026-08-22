import AppKit

@main
final class AppMain {
    static func main() {
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
    private lazy var panelController = NotchPanelController(
        stateModel: stateModel,
        engine: engine,
        settingsModel: settingsModel,
        nowPlaying: nowPlayingController
    )
    private lazy var settingsWindow = SettingsWindowController(
        settingsModel: settingsModel
    )

    private var batteryService: BatteryMonitorService?
    private var statusItem: NSStatusItem?
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        startBatteryMonitoring()
        installOutsideClickMonitor()
        nowPlayingController.start()
        panelController.show()

    }

    func applicationWillTerminate(_ notification: Notification) {
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
            accessibilityDescription: "notchFX"
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
        menu.addItem(withTitle: "Salir de notchFX", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenuState(menu)
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
