import AppKit
import StatusCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore()
    private lazy var settingsModel = SettingsModel(store: store)
    private let monitor = SystemMonitor()
    private let monitorModel = MonitorModel()
    private var sampler: Sampler?
    private var statusBar: StatusBarManager?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_: Notification) {
        // 状态栏 + 下拉浮窗
        let bar = StatusBarManager(settingsModel: settingsModel, monitorModel: monitorModel)
        bar.onOpenSettings = { [weak self] in self?.showSettings() }
        bar.onQuit = { NSApplication.shared.terminate(nil) }
        statusBar = bar

        // 采样调度：后台采集，写入 monitorModel（B8）；状态栏与浮窗都绑定它，随 1s 自动刷新
        let interval = settingsModel.value.refreshIntervalSeconds
        let model = monitorModel
        let sampler = Sampler(interval: interval, monitor: monitor) { [weak model] sample in
            Task { @MainActor in
                model?.sample = sample
            }
        }
        sampler.start()
        self.sampler = sampler

        // B4：监听系统唤醒，重置采集基线，丢弃下一次差值
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    func applicationWillTerminate(_: Notification) {
        sampler?.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc func didWake() {
        Task { await monitor.resetAfterWake() }
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settingsModel: settingsModel)
        }
        settingsWindowController?.show()
    }
}
