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
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = NotchPanelController(stateModel: stateModel)
        panelController?.show()

        let welcome = NotchActivity(
            id: ActivityID(rawValue: "m1.welcome"),
            kind: .timer
        )
        stateModel.present(welcome)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.stateModel.expand()
            self?.scheduleCollapse()
        }
    }

    private func scheduleCollapse() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.stateModel.collapse()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.hide()
    }
}
