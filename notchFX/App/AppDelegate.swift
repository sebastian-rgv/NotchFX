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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let stateModel = NotchStateModel()
    private lazy var engine = ActivityEngine(stateModel: stateModel)
    private lazy var timerController = LocalTimerController(engine: engine)
    private lazy var panelController = NotchPanelController(
        stateModel: stateModel,
        engine: engine
    )
    private var batteryService: BatteryMonitorService?
    private var statusItem: NSStatusItem?
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        startBatteryMonitoring()
        installOutsideClickMonitor()
        panelController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        batteryService?.stop()

        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        outsideClickMonitor = nil
    }

    private func installOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panelController.handleOutsideClick(at: NSEvent.mouseLocation)
            }
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.inset.filled",
            accessibilityDescription: "notchFX"
        )

        let menu = NSMenu()

        let demoTimer = NSMenuItem(
            title: "Temporizador demo (10 s)",
            action: #selector(startDemoTimer),
            keyEquivalent: ""
        )
        demoTimer.target = self
        menu.addItem(demoTimer)

        let testAlert = NSMenuItem(
            title: "Alerta de prueba",
            action: #selector(emitTestAlert),
            keyEquivalent: ""
        )
        testAlert.target = self
        menu.addItem(testAlert)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Salir de notchFX",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func startDemoTimer() {
        timerController.start(duration: 10)
    }

    @objc private func emitTestAlert() {
        engine.present(
            NotchActivity(
                id: ActivityID(rawValue: "test.alert.\(UUID().uuidString)"),
                kind: .battery,
                detail: .battery(percent: 42, isCharging: true)
            ),
            priority: .alert,
            ttl: 5
        )
    }

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
            ttl: 5
        )
    }
}
