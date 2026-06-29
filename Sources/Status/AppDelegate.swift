import AppKit
import StatusCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore()
    private lazy var settingsModel = SettingsModel(store: store)
    private let monitor = SystemMonitor()
    private var sampler: Sampler?
    private var statusBar: StatusBarManager?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_: Notification) {
        // 状态栏（含菜单）
        let bar = StatusBarManager(settingsModel: settingsModel)
        bar.onOpenSettings = { [weak self] in self?.showSettings() }
        bar.onQuit = { NSApplication.shared.terminate(nil) }
        statusBar = bar

        // 采样调度：后台采集，主线程刷新 UI（B8）
        let interval = settingsModel.value.refreshIntervalSeconds
        let sampler = Sampler(interval: interval, monitor: monitor) { [weak bar] sample in
            Task { @MainActor in bar?.update(with: sample) }
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
