import AppKit
import Combine
import StatusCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore()
    private lazy var settingsModel = SettingsModel(store: store)
    private lazy var monitor = SystemMonitor()
    private let monitorModel = MonitorModel()
    private var sampler: Sampler?
    private var statusBar: StatusBarManager?
    private var settingsWindowController: SettingsWindowController?
    private var refreshIntervalObserver: AnyCancellable?

    func applicationDidFinishLaunching(_: Notification) {
        // 状态栏 + 下拉浮窗
        let bar = StatusBarManager(settingsModel: settingsModel, monitorModel: monitorModel)
        bar.onOpenSettings = { [weak self] in self?.showSettings() }
        bar.onQuit = { NSApplication.shared.terminate(nil) }
        bar.shouldShowPopover = { [weak self] in
            guard self?.settingsWindowController?.isVisible != true else {
                self?.settingsWindowController?.show()
                return false
            }
            return true
        }
        statusBar = bar

        // 创建采样器
        startSampler(interval: settingsModel.value.refreshIntervalSeconds)

        // 监听刷新间隔变化
        refreshIntervalObserver = settingsModel.$value
            .map(\.refreshIntervalSeconds)
            .removeDuplicates()
            .sink { [weak self] interval in
                self?.updateSamplerInterval(interval)
            }

        // B4：监听系统唤醒，重置采集基线，丢弃下一次差值
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    private func startSampler(interval: TimeInterval) {
        let model = monitorModel
        let mon = monitor
        let sampler = Sampler(interval: interval, monitor: mon) { [weak model] sample in
            Task { @MainActor in
                model?.sample = sample
            }
        }
        sampler.start()
        self.sampler = sampler
    }

    private func updateSamplerInterval(_ interval: TimeInterval) {
        sampler?.stop()
        startSampler(interval: interval)
    }

    func applicationWillTerminate(_: Notification) {
        sampler?.stop()
        refreshIntervalObserver?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc func didWake() {
        Task { await monitor.resetAfterWake() }
    }

    func showSettings() {
        if settingsWindowController == nil {
            let controller = SettingsWindowController(settingsModel: settingsModel)
            controller.onClose = { [weak self] in
                self?.settingsWindowController = nil
            }
            settingsWindowController = controller
        }
        statusBar?.closePopover()
        settingsWindowController?.show()
    }
}
